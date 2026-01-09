import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder_model.dart';
import 'notification_service.dart';
import 'background_task_service.dart';
import 'voice_date_parser.dart';

class ReminderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save reminder to Firestore and schedule notification
  static Future<String?> saveReminder(ReminderModel reminder) async {
    try {
      final user = _auth.currentUser;
      print('Current user: ${user?.uid}');
      
      if (user == null) {
        print('User not authenticated');
        throw Exception('User not authenticated');
      }

      // Add user ID and timestamps
      final reminderWithUser = reminder.copyWith(
        createdBy: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Saving reminder to Firestore: ${reminderWithUser.toMap()}');

      // Save to Firestore
      final docRef = await _firestore.collection('reminders').add(reminderWithUser.toMap());
      print('Reminder saved with ID: ${docRef.id}');
      
      // Schedule local notification using enhanced background task service
      try {
        // Initialize notifications if not already done
        await NotificationService.initialize();
        await BackgroundTaskService.scheduleNewReminder(reminderWithUser.copyWith(id: docRef.id));
        print('Enhanced notification scheduled successfully');
      } catch (notificationError) {
        print('Error scheduling notification: $notificationError');
        // Don't fail the save if notification fails
      }
      
      print('Reminder save completed successfully');

      return docRef.id;
    } catch (e) {
      print('Error saving reminder: $e');
      print('Error type: ${e.runtimeType}');
      if (e is Exception) {
        print('Exception details: ${e.toString()}');
      }
      return null;
    }
  }

  // Update existing reminder
  static Future<bool> updateReminder(ReminderModel reminder) async {
    try {
      if (reminder.id == null) throw Exception('Reminder ID is required for update');

      // Cancel existing notification
      await BackgroundTaskService.cancelReminderNotification(reminder.id!);

      // Update in Firestore
      await _firestore.collection('reminders').doc(reminder.id).update(
        reminder.copyWith(updatedAt: DateTime.now()).toMap(),
      );

      // Schedule new notification using enhanced background task service
      await BackgroundTaskService.scheduleNewReminder(reminder);

      return true;
    } catch (e) {
      print('Error updating reminder: $e');
      return false;
    }
  }

  // Delete reminder
  static Future<bool> deleteReminder(String reminderId) async {
    try {
      // Cancel notification using enhanced background task service
      await BackgroundTaskService.cancelReminderNotification(reminderId);

      // Delete from Firestore
      await _firestore.collection('reminders').doc(reminderId).delete();

      return true;
    } catch (e) {
      print('Error deleting reminder: $e');
      return false;
    }
  }

  // Get reminder by ID
  static Future<ReminderModel?> getReminderById(String reminderId) async {
    try {
      final doc = await _firestore.collection('reminders').doc(reminderId).get();
      if (doc.exists && doc.data() != null) {
        return ReminderModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting reminder by ID: $e');
      return null;
    }
  }

  // Mark reminder as completed
  static Future<bool> markCompleted(String reminderId) async {
    try {
      await _firestore.collection('reminders').doc(reminderId).update({
        'isCompleted': true,
        'completedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Cancel notification using enhanced background task service
      await BackgroundTaskService.cancelReminderNotification(reminderId);

      return true;
    } catch (e) {
      print('Error marking reminder completed: $e');
      return false;
    }
  }

  // Get user's reminders stream - ONLY upcoming (present and future) reminders
  // NOTE: Simplified query to avoid Firestore composite index requirement
  // We filter by createdBy and isCompleted only, then filter dateTime on client side
  static Stream<List<ReminderModel>> getUserReminders() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final now = DateTime.now();

    return _firestore
        .collection('reminders')
        .where('createdBy', isEqualTo: user.uid)
        .where('isCompleted', isEqualTo: false)
        // Removed dateTime filter from query to avoid Firestore composite index requirement
        // We'll filter on client side instead - this shows ALL reminders (past and future)
        .snapshots()
        .map((snapshot) {
          try {
            final reminders = snapshot.docs
                .map((doc) {
                  try {
                    return ReminderModel.fromMap(doc.data(), doc.id);
                  } catch (e) {
                    print('Error parsing reminder document ${doc.id}: $e');
                    return null;
                  }
                })
                .where((reminder) => reminder != null)
                .cast<ReminderModel>()
                // Filter to show ONLY upcoming/future reminders (not past ones)
                // Allow a 5-minute buffer for reminders that just passed (due to timezone/clock differences)
                .where((reminder) => reminder.dateTime.isAfter(now.subtract(const Duration(minutes: 5))))
                .toList();
            
            // Sort by dateTime on the client side
            reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
            
            return reminders;
          } catch (e) {
            print('Error processing reminders snapshot: $e');
            return <ReminderModel>[];
          }
        })
        .handleError((error) {
          print('Error in getUserReminders stream: $error');
          // If it's an index error, log it but return empty list instead of crashing
          if (error.toString().contains('index')) {
            print('⚠️ Firestore index required. To fix, create the index at the URL shown in the error, or the query will work with client-side filtering.');
          }
          return <ReminderModel>[];
        });
  }

  /// Get ALL reminders for the user (completed + pending), sorted by date ascending.
  /// Used for screens like "All Reminders" where the UI applies its own filters.
  static Stream<List<ReminderModel>> getAllUserReminders() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('reminders')
        .where('createdBy', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          try {
            final reminders = snapshot.docs
                .map((doc) {
                  try {
                    return ReminderModel.fromMap(doc.data(), doc.id);
                  } catch (e) {
                    print('Error parsing reminder document ${doc.id}: $e');
                    return null;
                  }
                })
                .where((reminder) => reminder != null)
                .cast<ReminderModel>()
                .toList();

            reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
            return reminders;
          } catch (e) {
            print('Error processing all reminders snapshot: $e');
            return <ReminderModel>[];
          }
        });
  }

  /// Missed reminders: past reminders that are NOT completed.
  /// These should be visible in a dedicated screen, but must NOT trigger alerts.
  static Stream<List<ReminderModel>> getMissedReminders({Duration grace = const Duration(minutes: 1)}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('reminders')
        .where('createdBy', isEqualTo: user.uid)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          try {
            final now = DateTime.now();
            final cutoff = now.subtract(grace);

            final reminders = snapshot.docs
                .map((doc) {
                  try {
                    return ReminderModel.fromMap(doc.data(), doc.id);
                  } catch (e) {
                    print('Error parsing reminder document ${doc.id}: $e');
                    return null;
                  }
                })
                .where((reminder) => reminder != null)
                .cast<ReminderModel>()
                .where((reminder) => reminder.dateTime.isBefore(cutoff))
                .toList();

            // Most-recent missed first
            reminders.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            return reminders;
          } catch (e) {
            print('Error processing missed reminders snapshot: $e');
            return <ReminderModel>[];
          }
        });
  }

  // Schedule local notification (public method) - now uses enhanced background task service
  static Future<void> scheduleNotification(ReminderModel reminder) async {
    return BackgroundTaskService.scheduleNewReminder(reminder);
  }

  // Parse voice input to extract reminder details using enhanced parser
  static ReminderModel? parseVoiceInput(String voiceText, {String? userId}) {
    try {
      if (voiceText.trim().isEmpty) {
        print('⚠️ Voice text is empty');
        return null;
      }

      print('🎤 Parsing voice input: "$voiceText"');
      
      // Use the enhanced voice date parser
      final parsed = VoiceDateParser.parseDateTime(voiceText);
      
      String title = parsed['title']?.toString().trim() ?? '';
      DateTime dateTime = parsed['dateTime'] as DateTime? ?? DateTime.now().add(const Duration(hours: 1));
      String repeat = parsed['repeat']?.toString() ?? 'No Repeat';
      String snooze = parsed['snooze']?.toString() ?? '5 Min';
      String source = 'Voice';

      // If title is empty or too short after parsing, use original text (cleaned minimally)
      if (title.isEmpty || title.length < 2) {
        // Remove only the most basic prefixes
        title = voiceText.trim();
        final lower = voiceText.toLowerCase();
        if (lower.startsWith('remind me to ')) {
          title = voiceText.substring('remind me to '.length).trim();
        } else if (lower.startsWith('remind me of ')) {
          title = voiceText.substring('remind me of '.length).trim();
        } else if (lower.startsWith('remind me about ')) {
          title = voiceText.substring('remind me about '.length).trim();
        } else if (lower.startsWith('remind me ')) {
          title = voiceText.substring('remind me '.length).trim();
        }
        
        // If still empty, use original
      if (title.isEmpty) {
        title = voiceText;
        }
      }

      print('🎤 Voice parsing results:');
      print('  Original text: "$voiceText"');
      print('  Title: "$title"');
      print('  DateTime: $dateTime');
      print('  Date: ${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}');
      print('  Time: ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}');
      print('  Repeat: $repeat');
      print('  Snooze: $snooze');
      print('  Has explicit date: ${parsed['hasExplicitDate']}');
      print('  Has explicit time: ${parsed['hasExplicitTime']}');
      print('  Has explicit repeat: ${parsed['hasExplicitRepeat']}');
      print('  Has explicit snooze: ${parsed['hasExplicitSnooze']}');

      return ReminderModel(
        title: title,
        dateTime: dateTime,
        repeat: repeat,
        snooze: snooze,
        createdBy: userId ?? _auth.currentUser?.uid ?? '',
        source: source,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('❌ Error parsing voice input: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Format date and time for display
  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (reminderDate == today) {
      dateStr = 'Today';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$dateStr at $timeStr';
  }

  // Get success message after saving
  static String getSuccessMessage(ReminderModel reminder) {
    final formattedTime = _formatDateTime(reminder.dateTime);
    final snoozeText = reminder.snooze == 'Tomorrow' ? 'tomorrow' : '${reminder.snoozeDurationMinutes} minutes before';
    
    return '✅ Reminder set for $formattedTime. You\'ll get a voice alert $snoozeText.';
  }
}
