import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_keys.dart';
import 'email_parsing_service.dart';
import 'voice_date_parser.dart';

class OutlookParserService {
  static const String _clientId = ApiKeys.microsoftClientId;
  static const String _redirectUrl = 'com.reminder.reminderplus://auth';
  static const String _scope = 'https://graph.microsoft.com/Mail.Read';
  static const String _authorizationEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const String _tokenEndpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const String _graphEndpoint = 'https://graph.microsoft.com/v1.0/me/messages';

  static final FlutterAppAuth _appAuth = FlutterAppAuth();
  static String? _accessToken;
  static bool _isAuthenticated = false;

  // Authenticate with Microsoft Graph API
  static Future<bool> authenticate() async {
    try {
      // Check if client ID is configured
      if (_clientId == 'YOUR_MICROSOFT_CLIENT_ID' || _clientId.isEmpty) {
        print('❌ Microsoft Client ID not configured. Please set ApiKeys.microsoftClientId');
        throw Exception('Microsoft Client ID not configured. Please configure it in lib/constants/api_keys.dart');
      }

      print('🔐 Starting Microsoft Outlook authentication...');
      final AuthorizationTokenRequest tokenRequest = AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: _authorizationEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
        scopes: [_scope],
      );

      print('📱 Opening Microsoft OAuth flow...');
      final AuthorizationTokenResponse? result = await _appAuth.authorizeAndExchangeCode(tokenRequest);
      
      if (result == null || result.accessToken == null) {
        print('❌ Microsoft authentication failed: No access token received');
        return false;
      }

      _accessToken = result.accessToken;
      _isAuthenticated = true;

      // Save authentication state and token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('outlook_authenticated', true);
      await prefs.setString('outlook_access_token', _accessToken!);
      if (result.refreshToken != null) {
        await prefs.setString('outlook_refresh_token', result.refreshToken!);
      }

      print('✅ Microsoft Outlook authentication successful');
      return true;
    } catch (e) {
      print('❌ Outlook authentication error: $e');
      if (e.toString().contains('Client ID not configured')) {
        rethrow;
      }
      return false;
    }
  }

  // Check if Outlook is already connected
  static Future<bool> isConnected() async {
    if (_isAuthenticated && _accessToken != null) {
      return true;
    }
    return await _isAuthenticatedFromPrefs();
  }

  static Future<bool> _isAuthenticatedFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('outlook_authenticated') ?? false;
      if (isAuth) {
        // Try to restore the access token
        final token = prefs.getString('outlook_access_token');
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
          _isAuthenticated = true;
          return true;
        } else {
          // Token might have expired, clear the flag
          await prefs.setBool('outlook_authenticated', false);
        }
      }
      return false;
    } catch (e) {
      print('Error checking Outlook authentication from prefs: $e');
      return false;
    }
  }

  // Parse meeting emails from Outlook
  static Future<List<Map<String, dynamic>>> parseMeetingEmails() async {
    if (!_isAuthenticated || _accessToken == null) {
      throw Exception('Outlook not authenticated');
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
      print('Error parsing Outlook emails: $e');
      rethrow;
    }
  }

  // Search emails with specific keyword
  static Future<List<Map<String, dynamic>>> _searchEmails(String keyword) async {
    try {
      if (_accessToken == null) {
        print('❌ Outlook access token is null');
        return [];
      }

      // Microsoft Graph API search query - need to use $filter or $search properly
      // Note: $search might not work with all filters, so we'll use $filter instead
      final filter = "contains(subject, '$keyword') or contains(body/content, '$keyword')";
      final url = Uri.parse('$_graphEndpoint?\$filter=$filter&\$top=50&\$select=id,subject,body,receivedDateTime');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        print('❌ Outlook API error: ${response.statusCode} - ${response.body}');
        // If filter doesn't work, try a simpler approach
        if (response.statusCode == 400 || response.statusCode == 501) {
          // Try without filter - just get recent messages
          final simpleUrl = Uri.parse('$_graphEndpoint?\$top=50&\$select=id,subject,body,receivedDateTime&\$orderby=receivedDateTime desc');
          final simpleResponse = await http.get(
            simpleUrl,
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          );
          
          if (simpleResponse.statusCode == 200) {
            final data = json.decode(simpleResponse.body);
            final messages = data['value'] as List<dynamic>? ?? [];
            // Filter locally by keyword
            final filtered = messages.where((msg) {
              final subject = (msg['subject'] as String? ?? '').toLowerCase();
              final bodyContent = ((msg['body'] as Map?)?['content'] as String? ?? '').toLowerCase();
              return subject.contains(keyword.toLowerCase()) || bodyContent.contains(keyword.toLowerCase());
            }).toList();
            return filtered.cast<Map<String, dynamic>>();
          }
        }
        return [];
      }

      final data = json.decode(response.body);
      final messages = data['value'] as List<dynamic>? ?? [];
      
      return messages.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error searching Outlook: $e');
      return [];
    }
  }

  // Parse individual email message
  static Future<Map<String, dynamic>?> _parseEmailMessage(Map<String, dynamic> message) async {
    try {
      // Extract email content
      final subject = message['subject'] as String? ?? '';
      final body = _extractEmailBody(message);
      
      // Skip if no relevant content
      if (!_isMeetingRelated(subject, body)) return null;

      // Parse event details using NLP
      final eventDetails = _parseEventDetails(subject, body);
      if (eventDetails == null) return null;

      return {
        'title': eventDetails['title'] ?? subject,
        'time': eventDetails['time'],
        'source': 'Outlook',
        'description': eventDetails['description'] ?? body,
        'location': eventDetails['location'],
        'userId': EmailParsingService.getCurrentUserId(),
        'createdAt': DateTime.now().toIso8601String(),
        'emailId': message['id'],
        'rawSubject': subject,
      };
    } catch (e) {
      print('Error parsing Outlook message: $e');
      return null;
    }
  }

  // Extract email body content
  static String _extractEmailBody(Map<String, dynamic> message) {
    try {
      final bodyContent = message['body'] as Map<String, dynamic>?;
      if (bodyContent == null) return '';

      final content = bodyContent['content'] as String? ?? '';
      final contentType = bodyContent['contentType'] as String? ?? '';

      if (contentType.toLowerCase() == 'html') {
        return _stripHtmlTags(content);
      }

      return content.trim();
    } catch (e) {
      print('Error extracting Outlook email body: $e');
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
      'skype',
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
      print('Error parsing Outlook event details: $e');
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
      RegExp(r'(https?://[^\s]+skype\.com/[^\s]+)', caseSensitive: false),
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

  // Get user profile information
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (!_isAuthenticated || _accessToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching Outlook user profile: $e');
    }

    return null;
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

  // Disconnect Outlook
  static Future<void> disconnect() async {
    try {
      _accessToken = null;
      _isAuthenticated = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('outlook_authenticated');
      await prefs.remove('outlook_access_token');
    } catch (e) {
      print('Error disconnecting Outlook: $e');
    }
  }
}
