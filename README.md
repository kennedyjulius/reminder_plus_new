# Reminder Plus - Voice & Smart Reminder App

A comprehensive Flutter-based reminder application with advanced features including voice commands, screen scanning, email parsing, calendar integration, and intelligent notification management.

## 📱 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation & Setup](#installation--setup)
- [Core Services](#core-services)
- [Screens & UI Components](#screens--ui-components)
- [Data Models](#data-models)
- [API Integrations](#api-integrations)
- [Background Tasks](#background-tasks)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

Reminder Plus is a sophisticated reminder management application built with Flutter that combines multiple input methods and intelligent processing to create a seamless user experience. The app integrates voice recognition, OCR text extraction, email parsing, and calendar synchronization to provide users with multiple ways to create and manage reminders.

### Key Capabilities
- **Multi-modal Input**: Voice, manual entry, screen scanning, email parsing
- **Smart Processing**: AI-powered text extraction and date/time parsing
- **Calendar Integration**: Google Calendar and Calendly synchronization
- **Background Processing**: Automated reminder checking and notifications
- **Cross-platform**: iOS and Android support

## ✨ Features

### 1. Voice Command System
- **Speech-to-Text**: Real-time voice recognition for creating reminders
- **Natural Language Processing**: Intelligent parsing of voice commands
- **Voice Feedback**: Text-to-speech confirmation of actions
- **Multi-language Support**: Configurable language settings

### 2. Screen Scanning (OCR)
- **Image Capture**: Camera and gallery integration for screen photos
- **Text Extraction**: Google ML Kit OCR for text recognition
- **Smart Parsing**: Automatic date/time/event extraction from text
- **Event Preview**: Review and edit extracted information before saving
- **Edit Functionality**: Complete editing capabilities for extracted events

### 3. Email Integration
- **Gmail Integration**: OAuth 2.0 authentication with Gmail API
- **Outlook Integration**: Microsoft Graph API support
- **Email Parsing**: Automatic extraction of events from email content
- **Background Sync**: Periodic email checking for new events

### 4. Calendar Synchronization
- **Google Calendar**: Full integration with Google Calendar API
- **Calendly Integration**: Calendly v2 API support
- **Unified Reminders**: All calendar events converted to app reminders
- **Real-time Sync**: Automatic synchronization with external calendars

### 5. Smart Notifications
- **Custom Sounds**: User-selectable notification tones
- **Snooze Options**: Multiple snooze intervals (5min, 30min, 1hr, Tomorrow)
- **Background Processing**: Notifications work even when app is closed
- **Voice Alerts**: Optional text-to-speech for reminder content

### 6. Advanced Settings
- **Comprehensive Configuration**: Granular control over all app features
- **Theme Customization**: Light/dark themes with custom colors
- **Font Settings**: Adjustable font sizes and styles
- **Sync Preferences**: Configurable sync frequencies and options

## 🏗️ Architecture

### Technology Stack
- **Framework**: Flutter 3.0+
- **Backend**: Firebase (Firestore, Auth, Cloud Functions)
- **State Management**: Provider pattern
- **Local Storage**: SharedPreferences
- **Notifications**: flutter_local_notifications
- **Voice Processing**: speech_to_text, flutter_tts
- **OCR**: google_ml_kit
- **Image Processing**: image_picker
- **Calendar APIs**: googleapis, Calendly v2
- **Background Tasks**: workmanager, background_fetch

### Project Structure
```
lib/
├── constants/
│   └── colors.dart              # App color scheme
├── models/
│   ├── reminder_model.dart      # Reminder data structure
│   └── settings_model.dart      # Settings data structure
├── screens/
│   ├── splash_screen.dart       # App launch screen
│   ├── home_screen.dart         # Main dashboard
│   ├── add_reminder_screen.dart # Manual reminder creation
│   ├── reminder_details_screen.dart # Reminder management
│   ├── screen_scan_screen.dart  # OCR scanning interface
│   ├── voice_command_screen.dart # Voice input interface
│   ├── email_parsing_screen.dart # Email integration
│   └── settings_screen.dart     # App configuration
├── services/
│   ├── firebase_service.dart    # Firebase operations
│   ├── reminder_service.dart    # Reminder CRUD operations
│   ├── notification_service.dart # Local notifications
│   ├── settings_service.dart    # Settings management
│   ├── background_task_service.dart # Background processing
│   ├── google_calendar_service.dart # Google Calendar API
│   ├── calendly_service.dart    # Calendly API
│   └── calendar_sync_service.dart # Calendar synchronization
└── widgets/
    ├── action_button.dart       # Reusable action buttons
    └── reminder_card.dart       # Reminder display component
```

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- iOS 12.0+ / Android API 21+
- Firebase project setup
- Google Cloud Console configuration

### Installation Steps

1. **Clone the repository**
```bash
git clone <repository-url>
cd reminder_plus
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **iOS Setup**
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Firebase Configuration**
   - Add `google-services.json` to `android/app/`
   - Add `GoogleService-Info.plist` to `ios/Runner/`
   - Configure Firebase project settings

5. **Run the application**
```bash
flutter run
```

## 🔧 Core Services

### FirebaseService
**Purpose**: Centralized Firebase operations and user management

**Key Methods**:
- `getUserProfile()`: Retrieve user profile data
- `updateUserProfile()`: Update user information
- `getUserReminders()`: Fetch user's reminders
- `saveReminder()`: Store new reminder
- `updateReminder()`: Modify existing reminder
- `deleteReminder()`: Remove reminder

**Usage**:
```dart
final userDoc = await FirebaseService.getUserProfile();
final reminders = await FirebaseService.getUserReminders();
```

### ReminderService
**Purpose**: Reminder CRUD operations and business logic

**Key Methods**:
- `saveReminder(ReminderModel)`: Save reminder to Firestore
- `updateReminder(ReminderModel)`: Update existing reminder
- `deleteReminder(String id)`: Delete reminder by ID
- `parseVoiceInput(String)`: Parse voice commands into reminders
- `getSuccessMessage(ReminderModel)`: Generate success messages

**Data Flow**:
1. Create ReminderModel instance
2. Call saveReminder() method
3. Service handles Firestore storage
4. Automatic notification scheduling
5. Return reminder ID

### NotificationService
**Purpose**: Local notification management and scheduling

**Key Methods**:
- `initialize()`: Initialize notification system
- `showNotification()`: Display immediate notification
- `scheduleReminder()`: Schedule future notification
- `cancelNotification()`: Cancel scheduled notification
- `requestPermissions()`: Request notification permissions

**Features**:
- Custom notification sounds
- Snooze functionality
- Background processing
- Platform-specific configurations

### SettingsService
**Purpose**: User preferences and configuration management

**Key Methods**:
- `getSettings()`: Retrieve user settings
- `updateSettings(SettingsModel)`: Save settings changes
- `clearAllData()`: Reset all user data
- `getAvailableThemes()`: Get theme options
- `getAvailableFontSizes()`: Get font size options

**Storage**:
- Local: SharedPreferences
- Remote: Firestore
- Automatic synchronization

## 📱 Screens & UI Components

### HomeScreen
**Purpose**: Main dashboard displaying upcoming reminders and quick actions

**Components**:
- User greeting with time-based messages
- Action buttons (Email Events, Screen Scan, Voice Command)
- Upcoming reminders list
- Sync and settings buttons

**Key Features**:
- Real-time reminder updates
- Quick action access
- Responsive design
- Pull-to-refresh functionality

### AddReminderScreen
**Purpose**: Manual reminder creation with comprehensive options

**Input Methods**:
- Text input for reminder title
- Date picker for reminder date
- Time picker for reminder time
- Voice input with speech recognition
- Repeat options (No Repeat, Daily, Weekly, Monthly)
- Snooze settings (5 Min, 30 Min, 1 Hour, Custom)

**Validation**:
- Required field validation
- Date/time range validation
- Voice input parsing
- Error handling and user feedback

### ScreenScanScreen
**Purpose**: OCR-based reminder creation from images

**Workflow**:
1. **Image Capture**: Camera or gallery selection
2. **OCR Processing**: Google ML Kit text extraction
3. **Text Parsing**: Automatic date/time/title extraction
4. **Event Preview**: Review extracted information
5. **Edit Options**: Modify extracted data
6. **Save**: Create reminder from extracted data

**Supported Formats**:
- MM/DD/YYYY HH:MM AM/PM
- MM-DD-YYYY HH:MM AM/PM
- Month DD, YYYY HH:MM AM/PM
- Today/Tomorrow HH:MM AM/PM
- HH:MM AM/PM (assumes today)

### VoiceCommandScreen
**Purpose**: Voice-based reminder creation and app control

**Capabilities**:
- Speech-to-text conversion
- Natural language processing
- Voice command recognition
- Text-to-speech feedback
- Background noise filtering

**Supported Commands**:
- "Remind me to [task] at [time]"
- "Create reminder for [event] tomorrow"
- "Set alarm for [time]"
- Navigation commands (home, settings)

### SettingsScreen
**Purpose**: Comprehensive app configuration and preferences

**Configuration Sections**:
- **Reminder Settings**: Default times, snooze options, sounds
- **Email Integration**: Gmail/Outlook connection, sync settings
- **Calendar Integration**: Google Calendar/Calendly setup
- **Voice Settings**: Language, microphone, TTS options
- **Appearance**: Themes, colors, font sizes
- **Account & Privacy**: User management, data controls

## 📊 Data Models

### ReminderModel
**Purpose**: Core data structure for all reminders

**Properties**:
```dart
class ReminderModel {
  String? id;                    // Unique identifier
  String title;                  // Reminder title
  DateTime dateTime;             // Scheduled date/time
  String repeat;                 // Repeat pattern
  String snooze;                 // Snooze duration
  String createdBy;              // User ID
  String source;                 // Creation method
  String? externalId;            // External service ID
  Map<String, dynamic>? metadata; // Additional data
  DateTime createdAt;            // Creation timestamp
  DateTime updatedAt;            // Last update timestamp
}
```

**Source Types**:
- `"manual"`: Manually created
- `"voice"`: Voice command created
- `"ocr"`: Screen scan created
- `"email"`: Email parsed
- `"google"`: Google Calendar sync
- `"calendly"`: Calendly sync

### SettingsModel
**Purpose**: User preferences and app configuration

**Structure**:
```dart
class SettingsModel {
  ReminderSettings reminderSettings;
  EmailSettings emailSettings;
  SyncSettings syncSettings;
  VoiceSettings voiceSettings;
  AppearanceSettings appearanceSettings;
  CalendarSettings calendarSettings;
  DateTime updatedAt;
}
```

**Nested Settings**:
- **ReminderSettings**: Default times, sounds, vibration
- **EmailSettings**: Email integration preferences
- **SyncSettings**: Background sync configuration
- **VoiceSettings**: Speech recognition options
- **AppearanceSettings**: UI customization
- **CalendarSettings**: Calendar integration settings

## 🔌 API Integrations

### Google Calendar API
**Purpose**: Synchronize with Google Calendar events

**Authentication**: OAuth 2.0 with Google Sign-In
**Scopes Required**:
- `https://www.googleapis.com/auth/calendar.readonly`
- `https://www.googleapis.com/auth/calendar.events`

**Key Operations**:
- Fetch user's calendar events
- Parse event details (title, time, description)
- Convert to ReminderModel format
- Handle authentication and token refresh

**Implementation**:
```dart
class GoogleCalendarService {
  Future<bool> signIn();
  Future<List<ReminderModel>> fetchEvents();
  Future<void> signOut();
}
```

### Calendly API
**Purpose**: Synchronize with Calendly scheduled events

**Authentication**: Personal Access Token
**Endpoint**: `https://api.calendly.com/scheduled_events`

**Key Operations**:
- Fetch scheduled events
- Parse event details and invitee information
- Convert to ReminderModel format
- Handle API rate limiting

**Implementation**:
```dart
class CalendlyService {
  Future<bool> connect(String token);
  Future<List<ReminderModel>> fetchEvents();
  Future<void> disconnect();
}
```

### Gmail API
**Purpose**: Parse email content for event information

**Authentication**: OAuth 2.0
**Scopes Required**:
- `https://www.googleapis.com/auth/gmail.readonly`

**Key Operations**:
- Fetch recent emails
- Parse email content for dates/times
- Extract event information
- Create reminders from email content

## ⚙️ Background Tasks

### Android - WorkManager
**Purpose**: Periodic background processing for Android

**Tasks**:
- Check for due reminders every 15 minutes
- Sync calendar events
- Process email notifications
- Send local notifications

**Configuration**:
```dart
Workmanager.registerPeriodicTask(
  "reminder_check",
  "checkDueReminders",
  frequency: Duration(minutes: 15),
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
);
```

### iOS - BackgroundTasks
**Purpose**: Background processing for iOS

**Tasks**:
- Background app refresh
- Notification processing
- Calendar synchronization
- Email parsing

**Configuration**:
- Background Modes enabled in Info.plist
- Background fetch identifier configured
- Background processing tasks registered

## 🔧 Configuration

### Firebase Setup
1. **Create Firebase Project**
2. **Enable Authentication** (Email/Password, Google Sign-In)
3. **Configure Firestore** with security rules
4. **Add iOS/Android apps** to project
5. **Download configuration files**

### Google APIs Setup
1. **Google Cloud Console**
   - Enable Calendar API
   - Enable Gmail API
   - Create OAuth 2.0 credentials
2. **Configure OAuth consent screen**
3. **Add authorized redirect URIs**

### Calendly Setup
1. **Create Calendly account**
2. **Generate Personal Access Token**
3. **Configure API permissions**

### iOS Configuration
**Info.plist Permissions**:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access for screen scanning</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for image selection</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access for voice commands</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition for voice input</string>
```

### Android Configuration
**AndroidManifest.xml Permissions**:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

## 🐛 Troubleshooting

### Common Issues

#### Camera Crashes
**Problem**: App crashes when accessing camera
**Solution**: 
- Check iOS permissions in Info.plist
- Verify camera permissions are granted
- Test on physical device (not simulator)

#### Firebase Permission Denied
**Problem**: Firestore permission errors
**Solution**:
- Check Firebase security rules
- Verify user authentication
- Ensure proper Firestore configuration

#### Background Tasks Not Working
**Problem**: Background processing fails
**Solution**:
- Check platform-specific configurations
- Verify WorkManager/BackgroundTasks setup
- Test on physical devices

#### OCR Text Extraction Fails
**Problem**: Poor text recognition accuracy
**Solution**:
- Ensure good image quality
- Check lighting conditions
- Verify Google ML Kit setup
- Test with clear, high-contrast images

### Debug Commands
```bash
# Check Flutter doctor
flutter doctor

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean && flutter pub get
```

## 📈 Performance Considerations

### Memory Management
- Image compression for OCR processing
- Efficient text parsing algorithms
- Proper disposal of resources
- Background task optimization

### Network Optimization
- Efficient API calls
- Caching strategies
- Offline support
- Error handling and retry logic

### Battery Optimization
- Smart background processing
- Efficient notification scheduling
- Minimal CPU usage
- Platform-specific optimizations

## 🔮 Future Enhancements

### Planned Features
- **AI-Powered Suggestions**: Smart reminder recommendations
- **Location-Based Reminders**: GPS-triggered notifications
- **Team Collaboration**: Shared reminders and calendars
- **Advanced Analytics**: Usage patterns and insights
- **Widget Support**: Home screen widgets
- **Apple Watch Integration**: Watch app support

### Technical Improvements
- **Offline Support**: Full offline functionality
- **Performance Optimization**: Faster loading and processing
- **Enhanced Security**: End-to-end encryption
- **Accessibility**: Improved accessibility features
- **Internationalization**: Multi-language support

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📞 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the documentation

---

**Reminder Plus** - Making reminder management intelligent, intuitive, and effortless. 🚀# reminder_plus_new
# reminder_plus_new
