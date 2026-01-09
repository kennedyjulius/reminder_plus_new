import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'settings_service.dart';
import 'background_task_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
  }

  // Helper method to get current timezone name from settings
  static Future<String> _getCurrentTimezoneName() async {
    try {
      final settings = await SettingsService.getSettings();
      return settings.syncSettings.timezone;
    } catch (e) {
      return 'UTC';
    }
  }

  // Helper method to convert DateTime to TZDateTime using user's configured timezone
  static Future<tz.TZDateTime> _getTZDateTime(DateTime dateTime) async {
    String timezoneName = 'UTC';
    try {
      final settings = await SettingsService.getSettings();
      timezoneName = settings.syncSettings.timezone;
    } catch (e) {
      print('⚠️ Error getting timezone from settings, using UTC: $e');
    }
    
    // Get timezone location
    tz.Location timezoneLocation;
    try {
      timezoneLocation = tz.getLocation(timezoneName);
    } catch (e) {
      print('⚠️ Invalid timezone "$timezoneName", falling back to device local timezone: $e');
      timezoneLocation = tz.local;
    }
    
    // Convert the DateTime to the configured timezone
    // If dateTime is already in UTC, we interpret it as if it were in the configured timezone
    return tz.TZDateTime.from(dateTime, timezoneLocation);
  }

  // Create notification channels for Android
  static Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Main reminder channel
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Reminder Notifications',
      description: 'Notifications for reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Scheduled notifications channel
    const AndroidNotificationChannel scheduledChannel = AndroidNotificationChannel(
      'scheduled_channel',
      'Scheduled Reminders',
      description: 'Scheduled reminder notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Immediate notifications channel
    const AndroidNotificationChannel immediateChannel = AndroidNotificationChannel(
      'immediate_channel',
      'Immediate Notifications',
      description: 'Immediate notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Background notifications channel
    const AndroidNotificationChannel backgroundChannel = AndroidNotificationChannel(
      'background_channel',
      'Background Notifications',
      description: 'Notifications from background tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(reminderChannel);
    await androidPlugin?.createNotificationChannel(scheduledChannel);
    await androidPlugin?.createNotificationChannel(immediateChannel);
    await androidPlugin?.createNotificationChannel(backgroundChannel);
  }

  static Future<void> _requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  // Check if notifications are enabled on Android
  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS doesn't need this check
  }

  // Request notification permissions and return status
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS permissions are handled in initialization
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Delegate to BackgroundTaskService so we can mark completed / cancel scheduled notifications
      BackgroundTaskService.handleNotificationTap(payload);
    }
  }

  // Schedule a reminder notification with custom sound
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    String? customSound,
  }) async {
    // Get user's notification settings
    String soundFile = customSound ?? 'soft_chime.mp3';
    bool vibration = true;
    
    try {
      final settings = await SettingsService.getSettings();
      soundFile = settings.reminderSettings.notificationSound;
      vibration = settings.reminderSettings.vibration;
    } catch (e) {
      print('Error getting notification settings: $e');
    }

    // Create notification details with custom sound
    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminder Notifications',
      channelDescription: 'Notifications for reminders',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound(soundFile.split('.').first),
      enableVibration: vibration,
      vibrationPattern: vibration ? Int64List.fromList([0, 250, 250, 250]) : null,
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFF8A2BE2),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundFile,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledTime = await _getTZDateTime(scheduledTime);
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Cancel a scheduled notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Schedule a notification for a specific date and time
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? customSound,
  }) async {
    print('🔔 SCHEDULING NOTIFICATION');
    print('ID: $id');
    print('Title: $title');
    print('Body: $body');
    print('Scheduled Date: $scheduledDate');
    print('Payload: $payload');
    print('Custom Sound: $customSound');
    
    // Get user's notification settings
    String soundFile = customSound ?? 'soft_chime.mp3';
    bool vibration = true;
    
    try {
      final settings = await SettingsService.getSettings();
      soundFile = settings.reminderSettings.notificationSound;
      vibration = settings.reminderSettings.vibration;
      print('Settings loaded - Sound: $soundFile, Vibration: $vibration');
    } catch (e) {
      print('Error getting notification settings: $e');
    }

    final androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Reminders',
      channelDescription: 'Scheduled reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound(soundFile.split('.').first),
      enableVibration: vibration,
      vibrationPattern: vibration ? Int64List.fromList([0, 250, 250, 250]) : null,
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFF8A2BE2),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundFile,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert DateTime to TZDateTime using user's configured timezone
    final tzScheduledDate = await _getTZDateTime(scheduledDate);
    print('🌍 Scheduling in timezone: ${await _getCurrentTimezoneName()}');
    print('TZDateTime: $tzScheduledDate');
    final currentTZTime = await _getTZDateTime(DateTime.now());
    print('Time until notification: ${tzScheduledDate.difference(currentTZTime).inMinutes} minutes');

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('✅ Notification scheduled successfully with ID: $id');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Show immediate notification with custom sound
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? customSound,
  }) async {
    // Get user's notification settings
    String soundFile = customSound ?? 'soft_chime.mp3';
    bool vibration = true;
    
    try {
      final settings = await SettingsService.getSettings();
      soundFile = settings.reminderSettings.notificationSound;
      vibration = settings.reminderSettings.vibration;
    } catch (e) {
      print('Error getting notification settings: $e');
    }

    final androidDetails = AndroidNotificationDetails(
      'immediate_channel',
      'Immediate Notifications',
      channelDescription: 'Immediate notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound(soundFile.split('.').first),
      enableVibration: vibration,
      vibrationPattern: vibration ? Int64List.fromList([0, 250, 250, 250]) : null,
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFF8A2BE2),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundFile,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show notification for background task
  static Future<void> showBackgroundNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'background_channel',
      'Background Notifications',
      channelDescription: 'Notifications from background tasks',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('soft_chime'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      playSound: true,
      enableLights: true,
      ledColor: const Color(0xFF8A2BE2),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'soft_chime.mp3',
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Test notification method for debugging
  static Future<void> showTestNotification() async {
    await showNotification(
      id: 999,
      title: 'Test Notification',
      body: 'This is a test notification to verify the service is working.',
      payload: 'test',
    );
  }
}
