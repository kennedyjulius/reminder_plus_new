import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reminder_model.dart';
import 'reminder_service.dart';
import 'gmail_parser_service.dart';
import 'outlook_parser_service.dart';

class EmailParsingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if Gmail is connected
  static Future<bool> isGmailConnected() async {
    try {
      return await GmailParserService.isConnected();
    } catch (e) {
      print('Error checking Gmail connection: $e');
      return false;
    }
  }

  // Check if Outlook is connected
  static Future<bool> isOutlookConnected() async {
    try {
      return await OutlookParserService.isConnected();
    } catch (e) {
      print('Error checking Outlook connection: $e');
      return false;
    }
  }

  // Get current user ID
  static String getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  // Save parsed event to Firestore and create reminder
  static Future<bool> saveParsedEvent(Map<String, dynamic> eventData) async {
    try {
      print('📧 Attempting to save parsed event...');
      print('Event data: ${eventData.keys.toList()}');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        return false;
      }
      
      print('✅ User authenticated: ${user.uid}');

      // Validate required fields
      if (eventData['title'] == null || eventData['title'].toString().trim().isEmpty) {
        print('❌ Missing or empty title');
        return false;
      }

      // Parse the event time - handle both string and DateTime
      DateTime eventTime;
      try {
        if (eventData['time'] is String) {
          print('📅 Parsing time from string: ${eventData['time']}');
          eventTime = DateTime.parse(eventData['time']);
        } else if (eventData['time'] is DateTime) {
          print('📅 Time is already DateTime object');
          eventTime = eventData['time'];
        } else {
          print('❌ Invalid time format: ${eventData['time'].runtimeType}');
          return false;
        }
        print('✅ Event time parsed: $eventTime');
      } catch (e) {
        print('❌ Error parsing event time: $e');
        print('Time value: ${eventData['time']}');
        return false;
      }

      // Create reminder model
      print('📝 Creating reminder model...');
      final reminder = ReminderModel(
        title: eventData['title'].toString().trim(),
        dateTime: eventTime,
        repeat: 'No Repeat',
        snooze: '30 Min',
        createdBy: user.uid,
        source: eventData['source'] ?? 'Email',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to reminders collection
      print('💾 Saving reminder to Firestore...');
      final docRef = await _firestore.collection('reminders').add(reminder.toMap());
      print('✅ Reminder saved with ID: ${docRef.id}');
      
      // Save to parsed events collection for tracking
      print('💾 Saving to parsed_events collection...');
      try {
        await _firestore.collection('parsed_events').add({
          'title': eventData['title'],
          'time': eventTime.toIso8601String(),
          'source': eventData['source'] ?? 'Email',
          'description': eventData['description'] ?? '',
          'location': eventData['location'],
          'userId': user.uid,
          'reminderId': docRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'emailId': eventData['emailId'],
          'rawSubject': eventData['rawSubject'],
        });
        print('✅ Parsed event saved successfully');
      } catch (e) {
        print('⚠️ Warning: Could not save to parsed_events: $e');
        // Don't fail the overall save if this fails
      }

      // Schedule local notification
      print('🔔 Scheduling notification...');
      try {
        await ReminderService.scheduleNotification(reminder.copyWith(id: docRef.id));
        print('✅ Notification scheduled successfully');
      } catch (e) {
        print('⚠️ Warning: Error scheduling notification: $e');
        // Don't fail the save if notification fails
      }

      print('✅ Event saved successfully!');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error saving parsed event: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Get user's parsed events
  static Stream<List<Map<String, dynamic>>> getParsedEvents() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('parsed_events')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      } catch (e) {
        print('Error processing parsed events: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  // Delete parsed event
  static Future<bool> deleteParsedEvent(String eventId) async {
    try {
      // Get the event to find associated reminder
      final eventDoc = await _firestore.collection('parsed_events').doc(eventId).get();
      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final reminderId = eventData['reminderId'] as String?;

      // Delete the reminder if it exists
      if (reminderId != null) {
        await ReminderService.deleteReminder(reminderId);
      }

      // Delete the parsed event
      await _firestore.collection('parsed_events').doc(eventId).delete();

      return true;
    } catch (e) {
      print('Error deleting parsed event: $e');
      return false;
    }
  }

  // Update parsed event
  static Future<bool> updateParsedEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('parsed_events').doc(eventId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update associated reminder if it exists
      final eventDoc = await _firestore.collection('parsed_events').doc(eventId).get();
      if (eventDoc.exists) {
        final eventData = eventDoc.data()!;
        final reminderId = eventData['reminderId'] as String?;
        
        if (reminderId != null && updates.containsKey('time')) {
          try {
            final newDateTime = DateTime.parse(updates['time']);
            final reminder = ReminderModel(
              id: reminderId,
              title: updates['title'] ?? eventData['title'],
              dateTime: newDateTime,
              repeat: 'No Repeat',
              snooze: '30 Min',
              createdBy: eventData['userId'],
              source: 'Email',
              createdAt: (eventData['createdAt'] as Timestamp).toDate(),
              updatedAt: DateTime.now(),
            );
            
            await ReminderService.updateReminder(reminder);
          } catch (e) {
            print('Error updating associated reminder: $e');
          }
        }
      }

      return true;
    } catch (e) {
      print('Error updating parsed event: $e');
      return false;
    }
  }

  // Get parsing statistics
  static Future<Map<String, dynamic>> getParsingStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('parsed_events')
          .where('userId', isEqualTo: user.uid)
          .get();

      final events = snapshot.docs.map((doc) => doc.data()).toList();
      
      final gmailCount = events.where((e) => e['source'] == 'Gmail').length;
      final outlookCount = events.where((e) => e['source'] == 'Outlook').length;
      
      return {
        'totalEvents': events.length,
        'gmailEvents': gmailCount,
        'outlookEvents': outlookCount,
        'lastParsed': events.isNotEmpty 
            ? events.first['createdAt'] 
            : null,
      };
    } catch (e) {
      print('Error getting parsing stats: $e');
      return {};
    }
  }

  // Clear all parsed events for user
  static Future<bool> clearAllParsedEvents() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get all parsed events
      final snapshot = await _firestore
          .collection('parsed_events')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Delete associated reminders first
      for (final doc in snapshot.docs) {
        final eventData = doc.data();
        final reminderId = eventData['reminderId'] as String?;
        
        if (reminderId != null) {
          try {
            await ReminderService.deleteReminder(reminderId);
          } catch (e) {
            print('Error deleting reminder ${reminderId}: $e');
          }
        }
      }

      // Delete all parsed events
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return true;
    } catch (e) {
      print('Error clearing parsed events: $e');
      return false;
    }
  }

  // Validate event data before saving
  static bool validateEventData(Map<String, dynamic> eventData) {
    try {
      // Check required fields
      if (eventData['title'] == null || eventData['title'].toString().trim().isEmpty) {
        return false;
      }

      if (eventData['time'] == null) {
        return false;
      }

      // Validate time format
      DateTime.parse(eventData['time']);
      
      if (eventData['source'] == null || !['Gmail', 'Outlook'].contains(eventData['source'])) {
        return false;
      }

      return true;
    } catch (e) {
      print('Event data validation error: $e');
      return false;
    }
  }

  // Format event data for display
  static Map<String, dynamic> formatEventForDisplay(Map<String, dynamic> eventData) {
    try {
      final eventTime = DateTime.parse(eventData['time']);
      
      return {
        'title': eventData['title'] ?? 'Untitled Event',
        'time': eventTime,
        'timeFormatted': _formatDateTime(eventTime),
        'source': eventData['source'] ?? 'Unknown',
        'description': eventData['description'] ?? '',
        'location': eventData['location'],
        'createdAt': eventData['createdAt'],
      };
    } catch (e) {
      print('Error formatting event for display: $e');
      return eventData;
    }
  }

  // Format DateTime for display
  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == -1) {
      return 'Yesterday at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Check if event is in the past
  static bool isEventInPast(Map<String, dynamic> eventData) {
    try {
      final eventTime = DateTime.parse(eventData['time']);
      return eventTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // Get upcoming events count
  static Future<int> getUpcomingEventsCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('parsed_events')
          .where('userId', isEqualTo: user.uid)
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final eventData = doc.data();
        try {
          final eventTime = DateTime.parse(eventData['time']);
          if (eventTime.isAfter(now)) {
            count++;
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      return count;
    } catch (e) {
      print('Error getting upcoming events count: $e');
      return 0;
    }
  }
}
