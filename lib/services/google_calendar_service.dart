import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/reminder_model.dart';
import '../models/settings_model.dart';
import 'google_auth_service.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance = GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  cal.CalendarApi? _calendarApi;
  AuthClient? _authClient;
  final GoogleAuthService _authService = GoogleAuthService();

  // Initialize Google Calendar service
  Future<bool> initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user is already signed in
      if (!_authService.isCalendarConnected()) return false;

      final AuthClient? client = await _authService.authenticateCalendar();
      if (client == null) return false;

      _authClient = client;
      _calendarApi = cal.CalendarApi(_authClient!);
      return true;
    } catch (e) {
      print('Error initializing Google Calendar: $e');
      return false;
    }
  }

  // Sign in to Google Calendar
  Future<bool> signIn() async {
    try {
      final AuthClient? client = await _authService.authenticateCalendar();
      if (client == null) return false;

      _authClient = client;
      _calendarApi = cal.CalendarApi(_authClient!);

      return true;
    } catch (e) {
      print('Error signing in to Google Calendar: $e');
      return false;
    }
  }

  // Sign out from Google Calendar
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _calendarApi = null;
      _authClient = null;
      
      // Remove token from Firestore
      await _removeTokenFromFirestore();
    } catch (e) {
      print('Error signing out from Google Calendar: $e');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => _authService.isCalendarConnected() && _calendarApi != null;

  // Fetch events from Google Calendar
  Future<List<ReminderModel>> fetchEvents({
    DateTime? startTime,
    DateTime? endTime,
    int maxResults = 100,
  }) async {
    if (_calendarApi == null) {
      throw Exception('Google Calendar not initialized');
    }

    try {
      final now = DateTime.now();
      final start = startTime ?? now;
      final end = endTime ?? now.add(Duration(days: 30));

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start,
        timeMax: end,
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );

      final reminders = <ReminderModel>[];
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return reminders;

      for (final event in events.items ?? []) {
        if (event.start?.dateTime == null && event.start?.date == null) continue;
        
        DateTime eventTime;
        bool isAllDay = false;
        
        if (event.start?.dateTime != null) {
          eventTime = DateTime.parse(event.start!.dateTime!.toIso8601String());
        } else {
          // All-day event
          eventTime = DateTime.parse(event.start!.date!.toIso8601String());
          isAllDay = true;
        }

        // Skip past events
        if (eventTime.isBefore(now)) continue;

        final reminder = ReminderModel(
          title: event.summary ?? 'Untitled Event',
          dateTime: eventTime,
          repeat: 'No Repeat',
          snooze: '15 Min',
          createdBy: user.uid,
          source: 'google',
          externalId: event.id,
          metadata: {
            'description': event.description ?? '',
            'location': event.location ?? '',
            'isAllDay': isAllDay,
            'attendees': event.attendees?.map((a) => {
              'email': a.email,
              'displayName': a.displayName,
              'responseStatus': a.responseStatus,
            }).toList() ?? [],
            'organizer': {
              'email': event.organizer?.email,
              'displayName': event.organizer?.displayName,
            },
            'htmlLink': event.htmlLink,
            'hangoutLink': event.hangoutLink,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        reminders.add(reminder);
      }

      return reminders;
    } catch (e) {
      print('Error fetching Google Calendar events: $e');
      return [];
    }
  }

  // Sync events and create reminders
  Future<List<ReminderModel>> syncEvents() async {
    try {
      final events = await fetchEvents();
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
      print('Error syncing Google Calendar events: $e');
      return [];
    }
  }

  // Create reminder from Google Calendar event
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

  // Update existing reminder from Google Calendar event
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
          .where('source', isEqualTo: 'google')
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
        'calendarSettings.googleCalendarToken': token,
        'calendarSettings.googleCalendarConnected': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error saving token to Firestore: $e');
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
        'calendarSettings.googleCalendarToken': FieldValue.delete(),
        'calendarSettings.googleCalendarConnected': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error removing token from Firestore: $e');
    }
  }
}
