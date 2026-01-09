import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';
import '../models/settings_model.dart';
import 'google_calendar_service.dart';
import 'calendly_service.dart';
import 'notification_service.dart';

class CalendarSyncService {
  static final CalendarSyncService _instance = CalendarSyncService._internal();
  factory CalendarSyncService() => _instance;
  CalendarSyncService._internal();

  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  final CalendlyService _calendlyService = CalendlyService();

  // Initialize calendar sync service
  Future<void> initialize() async {
    try {
      await _googleCalendarService.initialize();
      await _calendlyService.initialize();
    } catch (e) {
      print('Error initializing calendar sync service: $e');
    }
  }

  // Sync all calendar sources
  Future<List<ReminderModel>> syncAllCalendars() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final settings = await _getUserSettings();
      if (settings == null) return [];

      final allReminders = <ReminderModel>[];

      // Sync Google Calendar if connected
      if (settings.calendarSettings.googleCalendarConnected) {
        try {
          final googleReminders = await _googleCalendarService.syncEvents();
          allReminders.addAll(googleReminders);
          print('Synced ${googleReminders.length} Google Calendar events');
        } catch (e) {
          print('Error syncing Google Calendar: $e');
        }
      }

      // Sync Calendly if connected
      if (settings.calendarSettings.calendlyConnected) {
        try {
          final calendlyReminders = await _calendlyService.syncEvents();
          allReminders.addAll(calendlyReminders);
          print('Synced ${calendlyReminders.length} Calendly events');
        } catch (e) {
          print('Error syncing Calendly: $e');
        }
      }

      // Schedule notifications for new reminders
      await _scheduleNotificationsForReminders(allReminders);

      return allReminders;
    } catch (e) {
      print('Error syncing all calendars: $e');
      return [];
    }
  }

  // Connect Google Calendar
  Future<bool> connectGoogleCalendar() async {
    try {
      final success = await _googleCalendarService.signIn();
      if (success) {
        // Update settings
        await _updateCalendarConnectionStatus('google', true);
        // Sync events immediately
        await syncAllCalendars();
      }
      return success;
    } catch (e) {
      print('Error connecting Google Calendar: $e');
      return false;
    }
  }

  // Disconnect Google Calendar
  Future<void> disconnectGoogleCalendar() async {
    try {
      await _googleCalendarService.signOut();
      await _updateCalendarConnectionStatus('google', false);
    } catch (e) {
      print('Error disconnecting Google Calendar: $e');
    }
  }

  // Connect Calendly
  Future<bool> connectCalendly(String accessToken) async {
    try {
      final success = await _calendlyService.setAccessToken(accessToken);
      if (success) {
        // Update settings
        await _updateCalendarConnectionStatus('calendly', true);
        // Sync events immediately
        await syncAllCalendars();
      }
      return success;
    } catch (e) {
      print('Error connecting Calendly: $e');
      return false;
    }
  }

  // Disconnect Calendly
  Future<void> disconnectCalendly() async {
    try {
      await _calendlyService.clearAccessToken();
      await _updateCalendarConnectionStatus('calendly', false);
    } catch (e) {
      print('Error disconnecting Calendly: $e');
    }
  }

  // Get connection status
  Map<String, bool> getConnectionStatus() {
    return {
      'google': _googleCalendarService.isSignedIn,
      'calendly': _calendlyService.isInitialized,
    };
  }

  // Schedule notifications for reminders
  Future<void> _scheduleNotificationsForReminders(List<ReminderModel> reminders) async {
    try {
      for (final reminder in reminders) {
        if (reminder.isDue) {
          // Schedule immediate notification
          await NotificationService.showNotification(
            id: reminder.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
            title: 'Reminder: ${reminder.title}',
            body: _getReminderBody(reminder),
            customSound: reminder.notificationSound,
          );
        } else {
          // Schedule future notification
          await NotificationService.scheduleReminder(
            id: reminder.id?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
            title: 'Reminder: ${reminder.title}',
            body: _getReminderBody(reminder),
            scheduledTime: reminder.dateTime,
            customSound: reminder.notificationSound,
          );
        }
      }
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  // Get reminder body text
  String _getReminderBody(ReminderModel reminder) {
    final source = reminder.source;
    final metadata = reminder.metadata;
    
    String body = '';
    
    if (source == 'google') {
      final location = metadata?['location'] as String?;
      final description = metadata?['description'] as String?;
      
      if (location?.isNotEmpty == true) {
        body += 'Location: $location\n';
      }
      if (description?.isNotEmpty == true) {
        body += description!;
      }
    } else if (source == 'calendly') {
      final meetingType = metadata?['meeting_type'] as String?;
      final duration = metadata?['meeting_duration'] as int?;
      final invitee = metadata?['invitee'] as Map<String, dynamic>?;
      
      if (meetingType?.isNotEmpty == true) {
        body += 'Meeting: $meetingType\n';
      }
      if (duration != null) {
        body += 'Duration: ${duration} minutes\n';
      }
      if (invitee?['name']?.isNotEmpty == true) {
        body += 'With: ${invitee!['name']}';
      }
    }
    
    return body.isNotEmpty ? body : 'Calendar event reminder';
  }

  // Update calendar connection status in settings
  Future<void> _updateCalendarConnectionStatus(String calendar, bool connected) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final field = calendar == 'google' 
          ? 'calendarSettings.googleCalendarConnected'
          : 'calendarSettings.calendlyConnected';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .update({
        field: connected,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating calendar connection status: $e');
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

  // Get unified reminders from all sources
  Future<List<ReminderModel>> getUnifiedReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .orderBy('dateTime', descending: false)
          .get();

      return query.docs
          .map((doc) => ReminderModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting unified reminders: $e');
      return [];
    }
  }

  // Delete reminder (including from external source if applicable)
  Future<bool> deleteReminder(ReminderModel reminder) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(reminder.id)
          .delete();

      // Cancel notification
      if (reminder.id != null) {
        await NotificationService.cancelNotification(reminder.id!.hashCode);
      }

      return true;
    } catch (e) {
      print('Error deleting reminder: $e');
      return false;
    }
  }

  // Update reminder
  Future<bool> updateReminder(ReminderModel reminder) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(reminder.id)
          .update(reminder.toMap());

      // Reschedule notification
      if (reminder.id != null) {
        await NotificationService.cancelNotification(reminder.id!.hashCode);
        await NotificationService.scheduleReminder(
          id: reminder.id!.hashCode,
          title: 'Reminder: ${reminder.title}',
          body: _getReminderBody(reminder),
          scheduledTime: reminder.dateTime,
          customSound: reminder.notificationSound,
        );
      }

      return true;
    } catch (e) {
      print('Error updating reminder: $e');
      return false;
    }
  }
}
