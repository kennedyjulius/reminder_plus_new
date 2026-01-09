import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'email_parsing_service.dart';
import 'google_auth_service.dart';
import 'voice_date_parser.dart';

class GmailParserService {
  static gmail.GmailApi? _gmailApi;
  static bool _isAuthenticated = false;
  static final GoogleAuthService _authService = GoogleAuthService();

  // Authenticate with Gmail API
  static Future<bool> authenticate() async {
    try {
      print('🔐 Starting Gmail authentication...');
      final AuthClient? client = await _authService.authenticateGmail();
      if (client == null) {
        print('❌ Gmail authentication failed: No auth client returned');
        return false;
      }

      // Initialize Gmail API
      _gmailApi = gmail.GmailApi(client);
      _isAuthenticated = true;

      // Save authentication state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gmail_authenticated', true);

      print('✅ Gmail authentication successful');
      return true;
    } catch (e) {
      print('❌ Gmail authentication error: $e');
      return false;
    }
  }

  // Check if Gmail is already connected
  static Future<bool> isConnected() async {
    if (_isAuthenticated && _gmailApi != null) {
      return true;
    }
    // Check Google Sign-In current user
    if (_authService.isGmailConnected()) {
      try {
        // Try to re-authenticate to refresh token
        final client = await _authService.authenticateGmail();
        if (client != null) {
          _gmailApi = gmail.GmailApi(client);
          _isAuthenticated = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('gmail_authenticated', true);
          return true;
        }
      } catch (e) {
        print('Error re-authenticating Gmail: $e');
      }
    }
    return await _isAuthenticatedFromPrefs();
  }

  static Future<bool> _isAuthenticatedFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('gmail_authenticated') ?? false;
      if (isAuth && _authService.isGmailConnected()) {
        // Try to re-initialize the API
        try {
          final client = await _authService.authenticateGmail();
          if (client != null) {
            _gmailApi = gmail.GmailApi(client);
            _isAuthenticated = true;
            return true;
          }
        } catch (e) {
          print('Error re-initializing Gmail API from prefs: $e');
          // Clear invalid auth state
          await prefs.setBool('gmail_authenticated', false);
        }
      }
      return false;
    } catch (e) {
      print('Error checking Gmail authentication from prefs: $e');
      return false;
    }
  }

  // Parse meeting emails from Gmail
  static Future<List<Map<String, dynamic>>> parseMeetingEmails() async {
    if (!_isAuthenticated || _gmailApi == null) {
      throw Exception('Gmail not authenticated');
    }

    try {
      // Search for emails with meeting-related keywords
      final List<String> keywords = [
        'meeting',
        'event',
        'appointment',
        'call',
        'conference',
        'reminder',
        'schedule',
      ];

      List<Map<String, dynamic>> events = [];

      for (final keyword in keywords) {
        final messages = await _searchEmails(keyword);
        for (final message in messages) {
          final event = await _parseEmailMessage(message);
          if (event != null) {
            events.add(event);
          }
        }
      }

      // Remove duplicates based on title and time
      return _removeDuplicateEvents(events);
    } catch (e) {
      print('Error parsing Gmail emails: $e');
      rethrow;
    }
  }

  // Search emails with specific keyword
  static Future<List<gmail.Message>> _searchEmails(String keyword) async {
    try {
      final query = 'subject:($keyword) OR body:($keyword) newer_than:30d';
      final response = await _gmailApi!.users.messages.list(
        'me',
        q: query,
        maxResults: 50,
      );

      if (response.messages == null) return [];

      List<gmail.Message> messages = [];
      for (final messageRef in response.messages!) {
        try {
          final message = await _gmailApi!.users.messages.get(
            'me',
            messageRef.id!,
            format: 'full',
          );
          messages.add(message);
        } catch (e) {
          print('Error fetching message ${messageRef.id}: $e');
        }
      }

      return messages;
    } catch (e) {
      print('Error searching Gmail: $e');
      return [];
    }
  }

  // Parse individual email message
  static Future<Map<String, dynamic>?> _parseEmailMessage(gmail.Message message) async {
    try {
      // Extract email content
      final subject = _extractHeader(message, 'Subject') ?? '';
      final body = _extractEmailBody(message);
      
      // Skip if no relevant content
      if (!_isMeetingRelated(subject, body)) return null;

      // Parse event details using NLP
      final eventDetails = _parseEventDetails(subject, body);
      if (eventDetails == null) return null;

      return {
        'title': eventDetails['title'] ?? subject,
        'time': eventDetails['time'],
        'source': 'Gmail',
        'description': eventDetails['description'] ?? body,
        'location': eventDetails['location'],
        'userId': EmailParsingService.getCurrentUserId(),
        'createdAt': DateTime.now().toIso8601String(),
        'emailId': message.id,
        'rawSubject': subject,
      };
    } catch (e) {
      print('Error parsing Gmail message: $e');
      return null;
    }
  }

  // Extract email header
  static String? _extractHeader(gmail.Message message, String headerName) {
    final headers = message.payload?.headers;
    if (headers == null) return null;

    for (final header in headers) {
      if (header.name?.toLowerCase() == headerName.toLowerCase()) {
        return header.value;
      }
    }
    return null;
  }

  // Extract email body content
  static String _extractEmailBody(gmail.Message message) {
    try {
      final payload = message.payload;
      if (payload == null) return '';

      // Get text/plain content
      String body = '';
      
      if (payload.body?.data != null) {
        body = utf8.decode(base64Url.decode(payload.body!.data!));
      } else if (payload.parts != null) {
        for (final part in payload.parts!) {
          if (part.mimeType == 'text/plain' && part.body?.data != null) {
            body += utf8.decode(base64Url.decode(part.body!.data!));
          } else if (part.mimeType == 'text/html' && part.body?.data != null) {
            // For HTML emails, we could parse and extract text
            final htmlContent = utf8.decode(base64Url.decode(part.body!.data!));
            body += _stripHtmlTags(htmlContent);
          }
        }
      }

      return body.trim();
    } catch (e) {
      print('Error extracting email body: $e');
      return '';
    }
  }

  // Strip HTML tags from content
  static String _stripHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Check if email is meeting-related
  static bool _isMeetingRelated(String subject, String body) {
    final content = '${subject.toLowerCase()} ${body.toLowerCase()}';
    
    final meetingKeywords = [
      'meeting',
      'event',
      'appointment',
      'call',
      'conference',
      'schedule',
      'reminder',
      'invitation',
      'calendar',
      'zoom',
      'teams',
      'google meet',
      'webex',
    ];

    final timeKeywords = [
      'am',
      'pm',
      'today',
      'tomorrow',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];

    final hasMeetingKeyword = meetingKeywords.any((keyword) => content.contains(keyword));
    final hasTimeKeyword = timeKeywords.any((keyword) => content.contains(keyword));

    return hasMeetingKeyword && hasTimeKeyword;
  }

  // Parse event details using enhanced NLP with VoiceDateParser
  static Map<String, dynamic>? _parseEventDetails(String subject, String body) {
    try {
      final content = '$subject\n$body';
      
      // Use VoiceDateParser for advanced date/time extraction
      final parsed = VoiceDateParser.parseDateTime(content);
      final eventTime = parsed['dateTime'] as DateTime?;
      
      if (eventTime == null) {
        // Fallback to basic parsing
        final fallbackTime = _parseDateTime(content);
        if (fallbackTime == null) return null;
      }

      // Extract title - prioritize subject line cleaned up
      String title = subject
          .replaceAll(RegExp(r'(re:|fwd?:)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll(RegExp(r'meeting:', caseSensitive: false), '')
          .replaceAll(RegExp(r'invitation:', caseSensitive: false), '')
          .trim();
      
      // If title is still generic, try to extract from body
      if (title.isEmpty || title.length < 3) {
        title = _extractTitleFromBody(body) ?? 'Meeting';
      }

      // Extract location using comprehensive patterns
      String? location = _extractLocation(content);
      
      // Extract meeting link (Zoom, Teams, Meet, etc.)
      String? meetingLink = _extractMeetingLink(content);
      if (meetingLink != null && location == null) {
        location = meetingLink;
      }
      
      // Extract attendees/participants
      List<String>? attendees = _extractAttendees(content);

      // Extract description (first few sentences of body, cleaned)
      String description = _extractDescription(body);
      
      // Add attendees to description if found
      if (attendees != null && attendees.isNotEmpty) {
        description += '\n\nAttendees: ${attendees.join(', ')}';
      }

      return {
        'title': title,
        'time': (eventTime ?? DateTime.now().add(const Duration(days: 1))).toIso8601String(),
        'description': description,
        'location': location,
        'meetingLink': meetingLink,
        'attendees': attendees,
      };
    } catch (e) {
      print('Error parsing event details: $e');
      return null;
    }
  }
  
  // Extract title from email body
  static String? _extractTitleFromBody(String body) {
    // Look for patterns like "Subject:", "Topic:", "Regarding:", etc.
    final patterns = [
      RegExp(r'subject[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'topic[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'regarding[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r're[:\s]+([^\n\r]+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final title = match.group(1)?.trim();
        if (title != null && title.length > 3) {
          return title;
        }
      }
    }
    
    // Extract first meaningful sentence
    final sentences = body.split(RegExp(r'[.!?]\s+'));
    for (final sentence in sentences) {
      final cleaned = sentence.trim();
      if (cleaned.length > 10 && cleaned.length < 100) {
        return cleaned;
      }
    }
    
    return null;
  }
  
  // Extract location from content
  static String? _extractLocation(String content) {
    final locationPatterns = [
      RegExp(r'location[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'where[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'venue[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'address[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'room[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'building[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'conference room[:\s]+([^\n\r]+)', caseSensitive: false),
    ];

    for (final pattern in locationPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final location = match.group(1)?.trim();
        if (location != null && location.isNotEmpty) {
          // Clean up the location (remove extra info)
          return location.split('\n').first.trim();
        }
      }
    }
    
    return null;
  }
  
  // Extract meeting link (Zoom, Teams, Google Meet, etc.)
  static String? _extractMeetingLink(String content) {
    final linkPatterns = [
      RegExp(r'(https?://[^\s]+zoom\.us/[^\s]+)', caseSensitive: false),
      RegExp(r'(https?://[^\s]+teams\.microsoft\.com/[^\s]+)', caseSensitive: false),
      RegExp(r'(https?://[^\s]+meet\.google\.com/[^\s]+)', caseSensitive: false),
      RegExp(r'(https?://[^\s]+webex\.com/[^\s]+)', caseSensitive: false),
      RegExp(r'(https?://[^\s]+gotomeeting\.com/[^\s]+)', caseSensitive: false),
    ];

    for (final pattern in linkPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    
    return null;
  }
  
  // Extract attendees/participants
  static List<String>? _extractAttendees(String content) {
    final attendeesPatterns = [
      RegExp(r'attendees[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'participants[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'invitees[:\s]+([^\n\r]+)', caseSensitive: false),
      RegExp(r'with[:\s]+([^\n\r]+)', caseSensitive: false),
    ];

    for (final pattern in attendeesPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final attendeesStr = match.group(1)?.trim();
        if (attendeesStr != null) {
          // Split by commas, semicolons, or "and"
          final attendees = attendeesStr
              .split(RegExp(r'[,;]|\sand\s', caseSensitive: false))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty && e.length > 2)
              .toList();
          
          if (attendees.isNotEmpty) {
            return attendees;
          }
        }
      }
    }
    
    return null;
  }
  
  // Extract and clean description
  static String _extractDescription(String body) {
    // Remove common email signatures and footers
    String cleaned = body;
    
    // Remove everything after common signature markers
    final signatureMarkers = [
      '\n--',
      '\n___',
      '\nBest regards',
      '\nBest,',
      '\nThanks,',
      '\nRegards,',
      '\nSincerely,',
      '\nSent from',
    ];
    
    for (final marker in signatureMarkers) {
      final index = cleaned.indexOf(marker);
      if (index > 0) {
        cleaned = cleaned.substring(0, index);
      }
    }
    
    // Remove excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Limit length
    if (cleaned.length > 300) {
      cleaned = '${cleaned.substring(0, 300)}...';
    }
    
    return cleaned.isNotEmpty ? cleaned : 'No description available';
  }

  // Remove duplicate events
  static List<Map<String, dynamic>> _removeDuplicateEvents(List<Map<String, dynamic>> events) {
    final seen = <String>{};
    return events.where((event) {
      final key = '${event['title']}_${event['time']}';
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    }).toList();
  }

  // Simple date parsing method
  static DateTime? _parseDateTime(String content) {
    try {
      // Look for common date patterns
      final patterns = [
        RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})'),
        RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false),
        RegExp(r'(today|tomorrow)', caseSensitive: false),
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(content);
        if (match != null) {
          final now = DateTime.now();
          
          if (match.group(0)?.toLowerCase() == 'today') {
            return now;
          } else if (match.group(0)?.toLowerCase() == 'tomorrow') {
            return now.add(const Duration(days: 1));
          }
        }
      }
      
      // Default to tomorrow if no date found
      return DateTime.now().add(const Duration(days: 1));
    } catch (e) {
      return null;
    }
  }

  // Disconnect Gmail
  static Future<void> disconnect() async {
    try {
      await _authService.signOut();
      _gmailApi = null;
      _isAuthenticated = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gmail_authenticated');
      await prefs.remove('gmail_user_email');
    } catch (e) {
      print('Error disconnecting Gmail: $e');
    }
  }
}
