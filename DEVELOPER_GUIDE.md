# Reminder Plus - Developer Quick Reference Guide

## 🚀 Quick Start

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Run on iOS
flutter run -d ios

# Run on Android
flutter run -d android

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

## 📁 Project Structure Quick Reference

```
lib/
├── constants/colors.dart          # App color scheme
├── models/                        # Data models
│   ├── reminder_model.dart        # Reminder data structure
│   └── settings_model.dart        # Settings data structure
├── screens/                       # UI screens
│   ├── home_screen.dart          # Main dashboard
│   ├── add_reminder_screen.dart  # Manual reminder creation
│   ├── screen_scan_screen.dart   # OCR scanning
│   ├── voice_command_screen.dart # Voice input
│   ├── email_parsing_screen.dart # Email integration
│   └── settings_screen.dart      # App settings
├── services/                      # Business logic
│   ├── firebase_service.dart     # Firebase operations
│   ├── reminder_service.dart     # Reminder CRUD
│   ├── notification_service.dart # Local notifications
│   ├── google_calendar_service.dart # Google Calendar API
│   ├── calendly_service.dart     # Calendly API
│   └── calendar_sync_service.dart # Calendar sync
└── widgets/                       # Reusable components
    ├── action_button.dart        # Action buttons
    └── reminder_card.dart        # Reminder display
```

## 🔧 Key Services Reference

### ReminderService
**Purpose**: Core reminder operations

```dart
// Save a reminder
final reminderId = await ReminderService.saveReminder(reminder);

// Update a reminder
await ReminderService.updateReminder(reminder);

// Delete a reminder
await ReminderService.deleteReminder(reminderId);

// Parse voice input
final reminder = ReminderService.parseVoiceInput("Remind me to call mom at 3 PM");
```

### NotificationService
**Purpose**: Local notification management

```dart
// Initialize notifications
await NotificationService.initialize();

// Show immediate notification
await NotificationService.showNotification(
  id: 1,
  title: 'Reminder',
  body: 'Time for your reminder!',
);

// Schedule future notification
await NotificationService.scheduleReminder(
  id: 1,
  title: 'Reminder',
  body: 'Time for your reminder!',
  scheduledTime: DateTime.now().add(Duration(hours: 1)),
);
```

### SettingsService
**Purpose**: User preferences management

```dart
// Get current settings
final settings = await SettingsService.getSettings();

// Update settings
await SettingsService.updateSettings(newSettings);

// Clear all data
await SettingsService.clearAllData();
```

## 📱 Screen Navigation

### Route Definitions
```dart
// In main.dart
routes: {
  '/home': (context) => const MainNavigation(),
  '/add-reminder': (context) => const AddReminderScreen(),
  '/screen-scan': (context) => const ScreenScanScreen(),
  '/voice-command': (context) => const VoiceCommandScreen(),
  '/email-parsing': (context) => const EmailParsingScreen(),
  '/settings': (context) => const SettingsScreen(),
}
```

### Navigation Examples
```dart
// Navigate to screen
Navigator.pushNamed(context, '/add-reminder');

// Navigate with arguments
Navigator.pushNamed(
  context,
  '/reminder-details',
  arguments: {'reminderId': reminderId},
);

// Navigate back
Navigator.pop(context);
```

## 🗃️ Data Models

### ReminderModel
```dart
final reminder = ReminderModel(
  title: 'Call Mom',
  dateTime: DateTime.now().add(Duration(hours: 1)),
  repeat: 'No Repeat',
  snooze: '5 Min',
  createdBy: 'user123',
  source: 'manual', // 'manual', 'voice', 'ocr', 'email', 'google', 'calendly'
  metadata: {'description': 'Important call'},
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### SettingsModel
```dart
final settings = SettingsModel(
  reminderSettings: ReminderSettings(
    defaultTime: '09:00',
    snooze: 10,
    notificationSound: 'default',
    vibration: true,
  ),
  emailSettings: EmailSettings(
    gmailConnected: false,
    outlookConnected: false,
    autoParse: true,
    syncInterval: '15min',
  ),
  // ... other settings
);
```

## 🔌 API Integration

### Google Calendar
```dart
final googleService = GoogleCalendarService();

// Sign in
final success = await googleService.signIn();

// Fetch events
final events = await googleService.fetchEvents();

// Sign out
await googleService.signOut();
```

### Calendly
```dart
final calendlyService = CalendlyService();

// Connect with token
final success = await calendlyService.connect('your-token');

// Fetch events
final events = await calendlyService.fetchEvents();

// Disconnect
await calendlyService.disconnect();
```

## 🎨 UI Components

### ActionButton
```dart
ActionButton(
  title: 'Screen Scan',
  icon: Icons.qr_code_scanner_outlined,
  gradient: AppColors.screenScanGradient,
  onTap: () => Navigator.pushNamed(context, '/screen-scan'),
)
```

### ReminderCard
```dart
ReminderCard(
  reminder: reminder,
  onTap: () => _navigateToDetails(reminder.id),
  onSnooze: () => _snoozeReminder(reminder.id),
  onDelete: () => _deleteReminder(reminder.id),
)
```

## 🔔 Notification Setup

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>
```

## 🐛 Common Issues & Solutions

### Camera Permission Denied
**Problem**: App crashes when accessing camera
**Solution**: 
1. Check iOS Info.plist has camera permissions
2. Request permissions at runtime
3. Test on physical device

### Firebase Permission Denied
**Problem**: Firestore operations fail
**Solution**:
1. Check Firebase security rules
2. Verify user authentication
3. Check Firestore configuration

### Background Tasks Not Working
**Problem**: Background processing fails
**Solution**:
1. Check platform-specific configurations
2. Verify WorkManager/BackgroundTasks setup
3. Test on physical devices

### OCR Text Extraction Poor Quality
**Problem**: Low accuracy in text recognition
**Solution**:
1. Ensure good image quality
2. Check lighting conditions
3. Verify Google ML Kit setup

## 🧪 Testing

### Unit Tests
```dart
// Test reminder parsing
test('should parse voice input correctly', () {
  final result = ReminderService.parseVoiceInput('Remind me to call mom at 3 PM');
  expect(result?.title, 'call mom');
  expect(result?.dateTime.hour, 15);
});
```

### Widget Tests
```dart
// Test reminder card
testWidgets('should display reminder title', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReminderCard(reminder: testReminder),
    ),
  );
  
  expect(find.text('Test Reminder'), findsOneWidget);
});
```

### Integration Tests
```dart
// Test full reminder creation flow
testWidgets('should create reminder from voice input', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to voice command screen
  await tester.tap(find.text('Voice Command'));
  await tester.pumpAndSettle();
  
  // Simulate voice input
  await tester.enterText(find.byType(TextField), 'Remind me to call mom at 3 PM');
  await tester.tap(find.text('Create Reminder'));
  await tester.pumpAndSettle();
  
  // Verify reminder was created
  expect(find.text('call mom'), findsOneWidget);
});
```

## 📊 Performance Tips

### Image Optimization
```dart
// Compress images before OCR processing
final compressedImage = await ImageProcessor.compressImage(imageFile);
```

### Lazy Loading
```dart
// Load reminders in batches
final reminders = await ReminderService.getReminders(
  page: currentPage,
  pageSize: 20,
);
```

### Caching
```dart
// Cache frequently accessed data
final cachedSettings = CacheManager.get<SettingsModel>('settings');
if (cachedSettings == null) {
  final settings = await SettingsService.getSettings();
  CacheManager.set('settings', settings);
}
```

## 🔒 Security Best Practices

### Secure Storage
```dart
// Store sensitive data securely
await SecureStorageService.storeToken('google_token', token);
```

### Input Validation
```dart
// Validate user input
if (title.trim().isEmpty) {
  throw ValidationException('Title cannot be empty');
}
```

### API Security
```dart
// Use secure headers for API calls
final response = await ApiSecurityService.secureGet(url);
```

## 📈 Monitoring & Debugging

### Logging
```dart
// Use structured logging
print('ReminderService: Saving reminder ${reminder.title}');
```

### Error Tracking
```dart
// Track errors for debugging
ErrorTracker.trackError(error, stackTrace, context: {'action': 'save_reminder'});
```

### Performance Monitoring
```dart
// Track performance metrics
PerformanceMonitor.trackApiCall('save_reminder', duration, success);
```

## 🚀 Deployment

### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Build iOS app
flutter build ios --release

# Archive for App Store
# Use Xcode to create archive
```

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google ML Kit Documentation](https://developers.google.com/ml-kit)
- [Google Calendar API Documentation](https://developers.google.com/calendar)
- [Calendly API Documentation](https://developer.calendly.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📞 Support

- Create an issue in the repository
- Check the troubleshooting section
- Review the technical documentation

---

**Happy Coding!** 🎉
