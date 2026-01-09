import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';
import '../models/settings_model.dart';

class CalendlyService {
  static final CalendlyService _instance = CalendlyService._internal();
  factory CalendlyService() => _instance;
  CalendlyService._internal();

  static const String _baseUrl = 'https://api.calendly.com';
  String? _accessToken;

  // Initialize Calendly service
  Future<bool> initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Load token from Firestore
      await _loadTokenFromFirestore();
      return _accessToken != null;
    } catch (e) {
      print('Error initializing Calendly: $e');
      return false;
    }
  }

  // Set access token
  Future<bool> setAccessToken(String token) async {
    try {
      _accessToken = token;
      await _saveTokenToFirestore(token);
      return true;
    } catch (e) {
      print('Error setting Calendly token: $e');
      return false;
    }
  }

  // Clear access token
  Future<void> clearAccessToken() async {
    try {
      _accessToken = null;
      await _removeTokenFromFirestore();
    } catch (e) {
      print('Error clearing Calendly token: $e');
    }
  }

  // Check if service is initialized
  bool get isInitialized => _accessToken != null;

  // Fetch scheduled events from Calendly
  Future<List<ReminderModel>> fetchScheduledEvents({
    DateTime? startTime,
    DateTime? endTime,
    int count = 100,
  }) async {
    if (_accessToken == null) {
      throw Exception('Calendly not initialized');
    }

    try {
      final now = DateTime.now();
      final start = startTime ?? now;
      final end = endTime ?? now.add(Duration(days: 30));

      final uri = Uri.parse('$_baseUrl/scheduled_events').replace(queryParameters: {
        'user': await _getCurrentUserUri(),
        'min_start_time': start.toIso8601String(),
        'max_start_time': end.toIso8601String(),
        'count': count.toString(),
        'sort': 'start_time:asc',
      });

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Calendly events: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final events = data['collection'] as List<dynamic>? ?? [];

      final reminders = <ReminderModel>[];
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return reminders;

      for (final eventData in events) {
        final event = eventData as Map<String, dynamic>;
        final startTime = DateTime.parse(event['start_time'] as String);
        
        // Skip past events
        if (startTime.isBefore(now)) continue;

        final reminder = ReminderModel(
          title: event['name'] ?? 'Calendly Event',
          dateTime: startTime,
          repeat: 'No Repeat',
          snooze: '15 Min',
          createdBy: user.uid,
          source: 'calendly',
          externalId: event['uri'] as String?,
          metadata: {
            'description': event['description'] ?? '',
            'location': event['location']?['location'] ?? '',
            'meeting_type': event['event_type']?['name'] ?? '',
            'meeting_duration': event['event_type']?['duration'] ?? 0,
            'invitee': {
              'name': event['invitees']?[0]?['name'] ?? '',
              'email': event['invitees']?[0]?['email'] ?? '',
            },
            'organizer': {
              'name': event['event_type']?['owner']?['name'] ?? '',
              'email': event['event_type']?['owner']?['email'] ?? '',
            },
            'status': event['status'] ?? '',
            'created_at': event['created_at'],
            'updated_at': event['updated_at'],
            'cancel_url': event['cancel_url'],
            'reschedule_url': event['reschedule_url'],
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        reminders.add(reminder);
      }

      return reminders;
    } catch (e) {
      print('Error fetching Calendly events: $e');
      return [];
    }
  }

  // Sync events and create reminders
  Future<List<ReminderModel>> syncEvents() async {
    try {
      final events = await fetchScheduledEvents();
      final reminders = <ReminderModel>[];
      
      for (final event in events) {
        // Check if reminder already exists
        final existingReminder = await _getExistingReminder(event.externalId!);
        if (existingReminder == null) {
          // Create new reminder
          final reminder = await _createReminderFromEvent(event);
          if (reminder != null) {
            reminders.add(reminder);
          }
        } else {
          // Update existing reminder if needed
          final updatedReminder = await _updateReminderFromEvent(existingReminder, event);
          if (updatedReminder != null) {
            reminders.add(updatedReminder);
          }
        }
      }

      return reminders;
    } catch (e) {
      print('Error syncing Calendly events: $e');
      return [];
    }
  }

  // Get current user URI for Calendly API
  Future<String> _getCurrentUserUri() async {
    try {
      final uri = Uri.parse('$_baseUrl/users/me');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get current user: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return data['resource']['uri'] as String;
    } catch (e) {
      print('Error getting current user URI: $e');
      rethrow;
    }
  }

  // Create reminder from Calendly event
  Future<ReminderModel?> _createReminderFromEvent(ReminderModel event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Get user settings for notification sound
      final settings = await _getUserSettings();
      final notificationSound = settings?.reminderSettings.notificationSound ?? 'soft_chime.mp3';

      final reminder = event.copyWith(
        notificationSound: notificationSound,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .add(reminder.toMap());

      return reminder;
    } catch (e) {
      print('Error creating reminder from event: $e');
      return null;
    }
  }

  // Update existing reminder from Calendly event
  Future<ReminderModel?> _updateReminderFromEvent(ReminderModel existing, ReminderModel event) async {
    try {
      // Check if event has been updated
      if (existing.title == event.title && 
          existing.dateTime == event.dateTime &&
          existing.metadata.toString() == event.metadata.toString()) {
        return null; // No changes
      }

      final updatedReminder = existing.copyWith(
        title: event.title,
        dateTime: event.dateTime,
        metadata: event.metadata,
        updatedAt: DateTime.now(),
      );

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(existing.createdBy)
          .collection('reminders')
          .doc(existing.id)
          .update(updatedReminder.toMap());

      return updatedReminder;
    } catch (e) {
      print('Error updating reminder from event: $e');
      return null;
    }
  }

  // Get existing reminder by external ID
  Future<ReminderModel?> _getExistingReminder(String externalId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .where('externalId', isEqualTo: externalId)
          .where('source', isEqualTo: 'calendly')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ReminderModel.fromMap(query.docs.first.data(), query.docs.first.id);
      }

      return null;
    } catch (e) {
      print('Error getting existing reminder: $e');
      return null;
    }
  }

  // Get user settings
  Future<SettingsModel?> _getUserSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .get();

      if (doc.exists) {
        return SettingsModel.fromMap(doc.data()!, doc.id);
      }

      return null;
    } catch (e) {
      print('Error getting user settings: $e');
      return null;
    }
  }

  // Save token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .update({
        'calendarSettings.calendlyToken': token,
        'calendarSettings.calendlyConnected': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  // Load token from Firestore
  Future<void> _loadTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final calendarSettings = data['calendarSettings'] as Map<String, dynamic>?;
        _accessToken = calendarSettings?['calendlyToken'] as String?;
      }
    } catch (e) {
      print('Error loading token from Firestore: $e');
    }
  }

  // Remove token from Firestore
  Future<void> _removeTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .update({
        'calendarSettings.calendlyToken': FieldValue.delete(),
        'calendarSettings.calendlyConnected': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error removing token from Firestore: $e');
    }
  }
}
