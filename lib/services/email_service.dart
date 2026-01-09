import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../models/reminder_model.dart';

class EmailService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends an email via the user's email app (opens the compose UI).
  /// This is the most reliable "works in Flutter" option without a backend,
  /// but it requires user interaction and cannot send silently in the background.
  static Future<bool> sendReminderEmailViaDevice(ReminderModel reminder) async {
    try {
      final user = _auth.currentUser;
      final toEmail = user?.email;
      if (toEmail == null || toEmail.trim().isEmpty) {
        print('❌ No user email available for device email compose');
        return false;
      }

      final dateTimeStr = _formatDateTime(reminder.dateTime);
      final body = _buildEmailBody(reminder, dateTimeStr);

      final email = Email(
        body: body,
        subject: '🔔 Reminder: ${reminder.title}',
        recipients: [toEmail],
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      print('✅ Email compose opened via device email app for: $toEmail');
      return true;
    } catch (e) {
      print('❌ Error sending reminder email via device: $e');
      return false;
    }
  }

  // Send reminder email to the logged-in user
  static Future<bool> sendReminderEmail(ReminderModel reminder) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        print('❌ No user email available for sending reminder email');
        return false;
      }

      print('📧 Sending reminder email to: ${user.email}');
      print('📧 Reminder: ${reminder.title}');
      print('📧 DateTime: ${reminder.dateTime}');

      // Format the reminder details
      final dateTimeStr = _formatDateTime(reminder.dateTime);
      final emailBody = _buildEmailBody(reminder, dateTimeStr);

      // Store in Firestore for a backend (Cloud Function) to process.
      // NOTE: Mobile apps cannot reliably send emails silently in the background.
      // If you need automatic emails, deploy a backend to process `email_queue`.
      try {
        await _queueEmailInFirestore(user.email!, reminder, emailBody);
        print('✅ Email queued in Firestore for processing');
        return true;
      } catch (e) {
        print('❌ Failed to queue email: $e');
      }

      return false;
    } catch (e) {
      print('❌ Error sending reminder email: $e');
      return false;
    }
  }

  // Queue email in Firestore for Cloud Function to process
  static Future<void> _queueEmailInFirestore(
    String email,
    ReminderModel reminder,
    String emailBody,
  ) async {
    try {
      await _firestore.collection('email_queue').add({
        'to': email,
        'subject': '🔔 Reminder: ${reminder.title}',
        'body': emailBody,
        'reminderId': reminder.id,
        'reminderTitle': reminder.title,
        'reminderDateTime': reminder.dateTime.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'reminder',
      });
      print('✅ Email queued in Firestore');
    } catch (e) {
      print('❌ Error queueing email in Firestore: $e');
      rethrow;
    }
  }

  // Build email body HTML/text
  static String _buildEmailBody(ReminderModel reminder, String dateTimeStr) {
    final buffer = StringBuffer();
    buffer.writeln('Hello,');
    buffer.writeln('');
    buffer.writeln('This is a reminder for:');
    buffer.writeln('');
    buffer.writeln('Title: ${reminder.title}');
    buffer.writeln('Date & Time: $dateTimeStr');
    buffer.writeln('Repeat: ${reminder.repeat}');
    buffer.writeln('Snooze: ${reminder.snooze}');
    buffer.writeln('Source: ${reminder.source}');
    buffer.writeln('');
    buffer.writeln('Please make sure to complete this reminder on time.');
    buffer.writeln('');
    buffer.writeln('Best regards,');
    buffer.writeln('Voice Reminder+');
    
    return buffer.toString();
  }

  // Format date and time for email
  static String _formatDateTime(DateTime dateTime) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (reminderDate == today) {
      dateStr = 'Today';
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${weekdays[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    
    return '$dateStr at $timeStr';
  }

  // Send immediate email notification (for due reminders)
  static Future<bool> sendDueReminderEmail(ReminderModel reminder) async {
    return await sendReminderEmail(reminder);
  }

  // Overdue emails are disabled (missed reminders should be visible but not alerted).
}



