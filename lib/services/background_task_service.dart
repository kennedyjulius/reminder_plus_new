import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import '../models/reminder_model.dart';
import '../models/settings_model.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'calendar_sync_service.dart';
import 'reminder_service.dart';
import 'native_notification_service.dart';
import 'stock_service.dart';
import 'holiday_service.dart';
import 'email_service.dart';

class BackgroundTaskService {
  static bool _isInitialized = false;
  static Timer? _periodicTimer;
  static DateTime? _lastHolidaySync;

  // Initialize notification system
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Initialize notification service
    await NotificationService.initialize();
    
    // Initialize native notification service for Android
    if (Platform.isAndroid) {
      await NativeNotificationService.initialize();
    }
    
    _isInitialized = true;
    print('Background task service initialized successfully');
    
    // Schedule all existing reminders in the background WITHOUT blocking
    // This ensures the UI loads immediately and shows loading indicators
    _scheduleAllReminders().catchError((error) {
      print('Error scheduling reminders in background: $error');
    });
  }

  // Start background tasks with periodic checking
  static Future<void> startBackgroundTasks() async {
    try {
      // Initialize without blocking (reminder scheduling happens in background)
      initialize().catchError((error) {
        print('Error initializing background tasks: $error');
      });
      
      // Start periodic timer for checking due reminders
      _periodicTimer?.cancel();
      _periodicTimer = Timer.periodic(
        const Duration(minutes: 5), // Check every 5 minutes
        (timer) async {
          await checkDueReminders();
          await StockService.processAlerts();
          await _maybeSyncHolidays();
        },
      );
      
      print('✅ Background tasks started successfully with periodic checking');
    } catch (e) {
      print('❌ Error starting background tasks: $e');
    }
  }

  // Stop background tasks
  static Future<void> stopBackgroundTasks() async {
    try {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      print('Background tasks stopped successfully');
    } catch (e) {
      print('Error stopping background tasks: $e');
    }
  }

  // Restart background tasks with new settings
  static Future<void> restartBackgroundTasks() async {
    await stopBackgroundTasks();
    await Future.delayed(const Duration(seconds: 2));
    await startBackgroundTasks();
  }

  // Public method to re-schedule all reminders (e.g., when timezone changes)
  static Future<void> rescheduleAllReminders() async {
    print('🔄 Re-scheduling all reminders (e.g., due to timezone change)...');
    await _scheduleAllReminders();
  }

  // Schedule all reminders as notifications
  // This runs in the background without blocking the UI
  static Future<void> _scheduleAllReminders() async {
    try {
      // Small delay to ensure UI has loaded first
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user logged in, skipping reminder scheduling');
        return;
      }

      print('📋 Starting background reminder scheduling...');

      // Get all active reminders
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('createdBy', isEqualTo: user.uid)
          .where('isCompleted', isEqualTo: false)
          .get();

      final totalReminders = remindersSnapshot.docs.length;
      print('📋 Found $totalReminders reminders to schedule');

      if (totalReminders == 0) {
        print('✅ No reminders to schedule');
        return;
      }

      // Process reminders in batches to avoid blocking
      int processed = 0;
      for (final doc in remindersSnapshot.docs) {
        try {
          final reminder = ReminderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          await _scheduleReminderNotification(reminder);
          processed++;
          
          // Yield to allow UI updates after every 5 reminders
          if (processed % 5 == 0) {
            await Future.delayed(const Duration(milliseconds: 50));
            print('📋 Progress: $processed/$totalReminders reminders scheduled');
          }
        } catch (e) {
          print('❌ Error scheduling reminder ${doc.id}: $e');
        }
      }
      
      print('✅ Completed scheduling $processed/$totalReminders reminders in background');
    } catch (e) {
      print('❌ Error scheduling reminders: $e');
    }
  }

  // Schedule a single reminder notification with multiple fallback notifications
  static Future<void> _scheduleReminderNotification(ReminderModel reminder) async {
    try {
      final now = DateTime.now();
      
      // Don't schedule reminders that are in the past (unless repeating)
      if (reminder.repeat == 'No Repeat' && reminder.dateTime.isBefore(now.subtract(const Duration(minutes: 5)))) {
        print('⏭️ Skipping past reminder: ${reminder.title} (${reminder.dateTime})');
        return;
      }
      
      print('=== SCHEDULING REMINDER NOTIFICATION ===');
      print('Reminder ID: ${reminder.id}');
      print('Reminder Title: ${reminder.title}');
      print('Reminder DateTime: ${reminder.dateTime}');
      print('Repeat: ${reminder.repeat}');
      print('Snooze: ${reminder.snooze}');
      print('Snooze Duration Minutes: ${reminder.snoozeDurationMinutes}');
      
      final settings = await SettingsService.getSettings();
      
      // Cancel existing notifications if any
      // Note: We cancel overdue notifications here in case they were scheduled before we disabled them
      await NotificationService.cancelNotification(reminder.id!.hashCode);
      await NotificationService.cancelNotification('${reminder.id}_exact'.hashCode);
      // Cancel any existing overdue notifications (for cleanup from previous versions)
      for (int i = 1; i <= 4; i++) {
        await NotificationService.cancelNotification('${reminder.id}_overdue_$i'.hashCode);
      }
      
      // Handle repeating reminders
      DateTime targetDateTime = reminder.dateTime;
      if (reminder.repeat != 'No Repeat') {
        final nextOccurrence = _getNextRepeatingOccurrence(reminder);
        if (nextOccurrence != null && nextOccurrence.isAfter(now)) {
          targetDateTime = nextOccurrence;
          print('🔄 Repeating reminder - Next occurrence: $targetDateTime');
        } else {
          print('⚠️ Could not calculate next occurrence for repeating reminder or it is in the past');
          return;
        }
      }
      
      // Calculate notification time
      // NOTE: Previously this used snoozeDurationMinutes to fire *before* the actual time.
      // This caused confusing behaviour where notifications could appear early/late.
      // We now always schedule the main notification at the exact reminder time.
      final notificationTime = targetDateTime;
      
      print('Calculated notification time (exact reminder time): $notificationTime');
      print('Current time: $now');
      print('Time difference: ${notificationTime.difference(now).inMinutes} minutes');

      // Don't schedule if the notification time has passed
      if (notificationTime.isBefore(now)) {
        print('❌ Notification time has passed for reminder: ${reminder.title}');
        return;
      }

      // Schedule the main notification at the calculated time (snooze time)
      print('📅 Scheduling snooze notification for: $notificationTime');
      
      bool scheduled = false;
      if (Platform.isAndroid) {
        // Use native Android notifications for better reliability
        scheduled = await NativeNotificationService.scheduleNotification(
          id: reminder.id!.hashCode,
          title: '🔔 Reminder: ${reminder.title}',
          body: 'Time for your reminder!',
          scheduledDate: notificationTime,
          payload: 'reminder_${reminder.id}',
        );
      } else {
        // Use flutter_local_notifications for iOS
        await NotificationService.scheduleNotification(
          id: reminder.id!.hashCode,
          title: '🔔 Reminder: ${reminder.title}',
          body: 'Time for your reminder!',
          scheduledDate: notificationTime,
          payload: 'reminder_${reminder.id}',
          customSound: settings.reminderSettings.notificationSound,
        );
        scheduled = true;
      }
      
      if (scheduled) {
        print('✅ Snooze notification scheduled successfully');
        
        // Also schedule email to be sent at the exact reminder time
        // We'll queue it in Firestore with a timestamp
        try {
          await EmailService.sendReminderEmail(reminder);
          print('✅ Reminder email queued for sending');
        } catch (emailError) {
          print('⚠️ Failed to queue reminder email: $emailError');
        }
      } else {
        print('❌ Failed to schedule snooze notification');
      }

      // Also schedule a notification at the exact reminder time (if snooze is not "Tomorrow")
      if (reminder.snooze != 'Tomorrow' && targetDateTime.isAfter(now)) {
        print('📅 Scheduling exact time notification for: $targetDateTime');
        
        bool exactScheduled = false;
        if (Platform.isAndroid) {
          // Use native Android notifications for better reliability
          exactScheduled = await NativeNotificationService.scheduleNotification(
            id: '${reminder.id}_exact'.hashCode,
            title: '🔔 ${reminder.title}',
            body: 'This is your reminder!',
            scheduledDate: targetDateTime,
            payload: 'exact_${reminder.id}',
          );
        } else {
          // Use flutter_local_notifications for iOS
          await NotificationService.scheduleNotification(
            id: '${reminder.id}_exact'.hashCode,
            title: '🔔 ${reminder.title}',
            body: 'This is your reminder!',
            scheduledDate: targetDateTime,
            payload: 'exact_${reminder.id}',
            customSound: settings.reminderSettings.notificationSound,
          );
          exactScheduled = true;
        }
        
        if (exactScheduled) {
          print('✅ Exact time notification scheduled successfully');
          
          // Schedule email to be sent at exact reminder time
          try {
            // We'll use a delayed email send - queue it with the reminder time
            await EmailService.sendReminderEmail(reminder);
            print('✅ Exact time reminder email queued');
          } catch (emailError) {
            print('⚠️ Failed to queue exact time reminder email: $emailError');
          }
        } else {
          print('❌ Failed to schedule exact time notification');
        }
      }
      
      // REMOVED: Overdue reminder notifications are disabled per user request
      // Users should only receive notifications at the scheduled time, not overdue reminders
      
      print('✅ All notifications scheduled for reminder: ${reminder.title}');
      print('✅ Snooze time: $notificationTime');
      print('✅ Exact time: ${reminder.dateTime}');
      print('✅ Overdue notifications: 0 (disabled)');
      print('=== NOTIFICATION SCHEDULING COMPLETE ===');
    } catch (e) {
      print('❌ Error scheduling notification for reminder ${reminder.id}: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Schedule a new reminder notification
  static Future<void> scheduleNewReminder(ReminderModel reminder) async {
    await _scheduleReminderNotification(reminder);
    
    // Check pending notifications after scheduling
    await _checkPendingNotifications();
  }

  // Cancel a reminder notification and all its overdue notifications
  static Future<void> cancelReminderNotification(String reminderId) async {
    try {
      if (Platform.isAndroid) {
        // Use native Android notifications for better reliability
        await NativeNotificationService.cancelNotification(reminderId.hashCode);
        await NativeNotificationService.cancelNotification('${reminderId}_exact'.hashCode);
        
        // Cancel all overdue notifications
        for (int i = 1; i <= 4; i++) {
          await NativeNotificationService.cancelNotification('${reminderId}_overdue_$i'.hashCode);
        }
      } else {
        // Use flutter_local_notifications for iOS
        await NotificationService.cancelNotification(reminderId.hashCode);
        await NotificationService.cancelNotification('${reminderId}_exact'.hashCode);
        
        // Cancel all overdue notifications
        for (int i = 1; i <= 4; i++) {
          await NotificationService.cancelNotification('${reminderId}_overdue_$i'.hashCode);
        }
      }
      
      print('Cancelled all notifications for reminder: $reminderId');
    } catch (e) {
      print('Error cancelling notifications for reminder $reminderId: $e');
    }
  }

  // Check for due reminders and send notifications
  static Future<void> checkDueReminders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user for background task');
        return;
      }

      print('Background task: Checking due reminders for user ${user.uid}');

      // Get user settings
      final settings = await SettingsService.getSettings();
      if (!settings.syncSettings.backgroundSync) {
        print('Background sync is disabled');
        return;
      }

      // Get current time
      final now = DateTime.now();
      // We do NOT alert missed/overdue reminders. This background check is only a safety net
      // for reminders that are essentially "right now".
      final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

      // Query Firestore for due reminders (due now or overdue)
      QuerySnapshot remindersSnapshot;
      try {
        remindersSnapshot = await FirebaseFirestore.instance
            .collection('reminders')
            .where('createdBy', isEqualTo: user.uid)
            .where('isCompleted', isEqualTo: false)
            .where('dateTime', isGreaterThanOrEqualTo: oneMinuteAgo)
            .where('dateTime', isLessThanOrEqualTo: now)
            .get();
        
        print('Found ${remindersSnapshot.docs.length} due reminders');
      } catch (e) {
        print('Error querying Firestore for due reminders: $e');
        return;
      }

      // Process each due reminder
      for (final doc in remindersSnapshot.docs) {
        try {
          final reminder = ReminderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          
          // Only alert if it's within the last 1 minute (do not alert missed reminders)
          final minutesLate = now.difference(reminder.dateTime).inMinutes;
          if (minutesLate >= 0 && minutesLate <= 1) {
            await _sendReminderNotification(reminder, settings);
          } else {
            print('⏭️ Skipping missed reminder alert (will be shown in Missed Reminders): ${reminder.title} (${reminder.dateTime})');
          }
        } catch (e) {
          print('Error processing reminder ${doc.id}: $e');
        }
      }

    } catch (e) {
      print('Error in checkDueReminders: $e');
    }
  }

  // Sync holidays at most once every 12 hours to avoid rate limits
  static Future<void> _maybeSyncHolidays() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      if (_lastHolidaySync != null &&
          now.difference(_lastHolidaySync!).inHours < 12) {
        return;
      }

      // Default to US if user has not chosen; this is a safe fallback
      await HolidayService.syncUpcomingHolidays(country: 'US', daysAhead: 60);
      _lastHolidaySync = now;
    } catch (e) {
      print('Error syncing holidays: $e');
    }
  }

  // NOTE: Test background notifications removed to avoid user spam.

  // Send notification for due reminder
  static Future<void> _sendReminderNotification(
    ReminderModel reminder, 
    SettingsModel settings
  ) async {
    try {
      // Send local notification
      await NotificationService.showNotification(
        id: reminder.id!.hashCode,
        title: '🔔 Reminder: ${reminder.title}',
        body: 'Time for your reminder!',
        payload: 'reminder_${reminder.id}',
        customSound: settings.reminderSettings.notificationSound,
      );
      print('Due notification sent for reminder: ${reminder.title}');
      
      // Send email notification
      try {
        await EmailService.sendDueReminderEmail(reminder);
        print('✅ Reminder email sent successfully');
      } catch (emailError) {
        print('⚠️ Failed to send reminder email: $emailError');
        // Don't fail the notification if email fails
      }
    } catch (e) {
      print('Error sending due notification: $e');
    }
  }

  // Manual method to test notifications
  static Future<void> testNotification() async {
    try {
      final settings = await SettingsService.getSettings();
      
      // Test immediate notification first
      await NotificationService.showNotification(
        id: 999,
        title: '🔔 Test Immediate Notification',
        body: 'This is an immediate test notification!',
        payload: 'test_immediate',
        customSound: settings.reminderSettings.notificationSound,
      );
      print('Immediate test notification sent successfully');
      
      // Test scheduled notification for 10 seconds from now
      if (Platform.isAndroid) {
        // Use native Android notifications for better reliability
        final success = await NativeNotificationService.testNotification();
        if (success) {
          print('✅ Native Android test notification scheduled successfully (10 seconds from now)');
        } else {
          print('❌ Failed to schedule native Android test notification');
        }
      } else {
        // Use flutter_local_notifications for iOS
        await NotificationService.scheduleNotification(
          id: 998,
          title: '🔔 Test Scheduled Notification',
          body: 'This is a scheduled test notification!',
          scheduledDate: DateTime.now().add(const Duration(seconds: 10)),
          payload: 'test_scheduled',
          customSound: settings.reminderSettings.notificationSound,
        );
        print('Scheduled test notification sent successfully (10 seconds from now)');
      }
      
      // Check pending notifications
      await _checkPendingNotifications();
      
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }

  // Check pending notifications for debugging
  static Future<void> _checkPendingNotifications() async {
    try {
      final pending = await NotificationService.getPendingNotifications();
      print('📋 PENDING NOTIFICATIONS: ${pending.length}');
      for (final notification in pending) {
        print('  - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  // Handle notification tap - mark reminder as completed if it's a main reminder
  static Future<void> handleNotificationTap(String payload) async {
    try {
      if (payload.startsWith('reminder_') || payload.startsWith('exact_')) {
        final reminderId = payload.replaceFirst('reminder_', '').replaceFirst('exact_', '');
        print('Notification tapped for reminder: $reminderId');
        
        // Mark reminder as completed
        final reminder = await ReminderService.getReminderById(reminderId);
        if (reminder != null) {
          final completedReminder = reminder.copyWith(
            isCompleted: true,
            updatedAt: DateTime.now(),
          );
          
          await ReminderService.updateReminder(completedReminder);
          
          // Cancel all related notifications
          await cancelReminderNotification(reminderId);
          
          print('Reminder marked as completed: $reminderId');
        }
      } else if (payload.startsWith('overdue_')) {
        final parts = payload.split('_');
        if (parts.length >= 2) {
          final reminderId = parts[1];
          print('Overdue notification tapped for reminder: $reminderId');
          
          // You could navigate to the reminder details or mark as completed
          // For now, just log the tap
        }
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  // Get the next occurrence for a repeating reminder
  static DateTime? _getNextRepeatingOccurrence(ReminderModel reminder) {
    final now = DateTime.now();
    final intervalMinutes = reminder.repeatIntervalMinutes;
    
    if (intervalMinutes == 0) return null;
    
    // For specific weekdays, find the next occurrence of that weekday
    if (reminder.repeat.startsWith('Every ')) {
      final weekdayName = reminder.repeat.substring(6); // Remove "Every "
      final weekdays = {
        'Monday': DateTime.monday,
        'Tuesday': DateTime.tuesday,
        'Wednesday': DateTime.wednesday,
        'Thursday': DateTime.thursday,
        'Friday': DateTime.friday,
        'Saturday': DateTime.saturday,
        'Sunday': DateTime.sunday,
      };
      
      if (weekdays.containsKey(weekdayName)) {
        final targetWeekday = weekdays[weekdayName]!;
        final currentWeekday = now.weekday;
        
        int daysToAdd = targetWeekday - currentWeekday;
        if (daysToAdd <= 0) {
          daysToAdd += 7; // Next week
        }
        
        final nextWeekday = now.add(Duration(days: daysToAdd));
        return DateTime(
          nextWeekday.year,
          nextWeekday.month,
          nextWeekday.day,
          reminder.dateTime.hour,
          reminder.dateTime.minute,
        );
      }
    }
    
    // For other repeat intervals, calculate based on minutes
    DateTime next = reminder.dateTime;
    while (next.isBefore(now)) {
      next = next.add(Duration(minutes: intervalMinutes));
    }
    
    return next;
  }
}