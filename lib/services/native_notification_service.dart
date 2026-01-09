import 'package:flutter/services.dart';
import 'dart:io';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('native_notifications');
  static bool _isInitialized = false;

  // Initialize the native notification service
  static Future<void> initialize() async {
    if (_isInitialized || !Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      print('✅ Native notification service initialized');
    } catch (e) {
      print('❌ Error initializing native notification service: $e');
    }
  }

  // Schedule a notification using native Android AlarmManager
  static Future<bool> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!Platform.isAndroid) {
      print('❌ Native notifications only supported on Android');
      return false;
    }

    try {
      final triggerTime = scheduledDate.millisecondsSinceEpoch;
      
      print('🔔 NATIVE SCHEDULING NOTIFICATION');
      print('ID: $id');
      print('Title: $title');
      print('Body: $body');
      print('Scheduled Date: $scheduledDate');
      print('Trigger Time: $triggerTime');
      print('Payload: $payload');

      final result = await _channel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'body': body,
        'triggerTime': triggerTime,
        'payload': payload ?? '',
      });

      print('✅ Native notification scheduled: $result');
      return result == true;
    } catch (e) {
      print('❌ Error scheduling native notification: $e');
      return false;
    }
  }

  // Cancel a notification
  static Future<bool> cancelNotification(int id) async {
    if (!Platform.isAndroid) return false;

    try {
      print('🗑️ Cancelling native notification: $id');
      final result = await _channel.invokeMethod('cancelNotification', {
        'id': id,
      });
      print('✅ Native notification cancelled: $result');
      return result == true;
    } catch (e) {
      print('❌ Error cancelling native notification: $e');
      return false;
    }
  }

  // Test method to schedule a notification in 10 seconds
  static Future<bool> testNotification() async {
    if (!Platform.isAndroid) return false;

    try {
      final testTime = DateTime.now().add(const Duration(seconds: 10));
      return await scheduleNotification(
        id: 777,
        title: '🔔 Native Test Notification',
        body: 'This is a native Android notification test!',
        scheduledDate: testTime,
        payload: 'native_test',
      );
    } catch (e) {
      print('❌ Error in test notification: $e');
      return false;
    }
  }
}
