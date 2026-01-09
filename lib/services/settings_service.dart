import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/settings_model.dart';

class SettingsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static SharedPreferences? _prefs;
  static SettingsModel? _cachedSettings;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize timezone data
    tz.initializeTimeZones();
  }
  
  // Detect device timezone and return IANA timezone name
  static String detectDeviceTimezone() {
    try {
      // Get the device's local timezone location
      final deviceLocation = tz.local;
      final deviceName = deviceLocation.name;
      
      print('🌍 Device timezone detected: $deviceName');
      
      // Map common device timezone names to IANA timezone names
      // This is a simplified mapping - in production, you might want a more comprehensive map
      final timezoneMap = {
        'America/New_York': 'America/New_York',
        'America/Chicago': 'America/Chicago',
        'America/Denver': 'America/Denver',
        'America/Los_Angeles': 'America/Los_Angeles',
        'America/Phoenix': 'America/Phoenix',
        'America/Toronto': 'America/Toronto',
        'America/Vancouver': 'America/Vancouver',
        'Europe/London': 'Europe/London',
        'Europe/Paris': 'Europe/Paris',
        'Europe/Berlin': 'Europe/Berlin',
        'Europe/Rome': 'Europe/Rome',
        'Europe/Madrid': 'Europe/Madrid',
        'Asia/Tokyo': 'Asia/Tokyo',
        'Asia/Shanghai': 'Asia/Shanghai',
        'Asia/Hong_Kong': 'Asia/Hong_Kong',
        'Asia/Singapore': 'Asia/Singapore',
        'Asia/Dubai': 'Asia/Dubai',
        'Asia/Kolkata': 'Asia/Kolkata',
        'Asia/Karachi': 'Asia/Karachi',
        'Australia/Sydney': 'Australia/Sydney',
        'Australia/Melbourne': 'Australia/Melbourne',
        'Pacific/Auckland': 'Pacific/Auckland',
        'Africa/Lagos': 'Africa/Lagos',
        'Africa/Johannesburg': 'Africa/Johannesburg',
        'America/Sao_Paulo': 'America/Sao_Paulo',
        'America/Mexico_City': 'America/Mexico_City',
        'America/Buenos_Aires': 'America/Buenos_Aires',
      };
      
      // If the device timezone name is already in our map, use it
      if (timezoneMap.containsKey(deviceName)) {
        return deviceName;
      }
      
      // Try to get timezone by checking offset
      final now = tz.TZDateTime.now(deviceLocation);
      final offset = now.timeZoneOffset;
      
      // Map common offsets to timezones (this is approximate)
      // This is a fallback for when exact name doesn't match
      if (offset.inHours == -5) return 'America/New_York'; // EST
      if (offset.inHours == -6) return 'America/Chicago'; // CST
      if (offset.inHours == -7) return 'America/Denver'; // MST
      if (offset.inHours == -8) return 'America/Los_Angeles'; // PST
      if (offset.inHours == 0) return 'Europe/London'; // GMT
      if (offset.inHours == 1) return 'Europe/Paris'; // CET
      if (offset.inHours == 5.5) return 'Asia/Kolkata'; // IST
      if (offset.inHours == 8) return 'Asia/Shanghai'; // CST
      if (offset.inHours == 9) return 'Asia/Tokyo'; // JST
      if (offset.inHours == 10) return 'Australia/Sydney'; // AEST
      
      // If no match, return device name (might work if it's a valid IANA name)
      return deviceName;
    } catch (e) {
      print('⚠️ Error detecting device timezone: $e');
      return 'UTC';
    }
  }

  // Get settings (from cache, local, or remote)
  static Future<SettingsModel> getSettings() async {
    if (_cachedSettings != null) return _cachedSettings!;

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Try to get from cache first
    if (_cachedSettings != null) return _cachedSettings!;

    // Try to get from local storage
    final localSettings = await _getLocalSettings(user.uid);
    if (localSettings != null) {
      _cachedSettings = localSettings;
      return localSettings;
    }

    // Try to get from Firestore
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        final settings = SettingsModel.fromMap(doc.data()!, doc.id);
        _cachedSettings = settings;
        await _saveLocalSettings(settings);
        return settings;
      }
    } catch (e) {
      print('Error loading settings from Firestore: $e');
    }

    // Create default settings with detected timezone if not set
    final defaultSettings = SettingsModel.defaultSettings(user.uid);
    
    // If timezone is still UTC (default), detect device timezone
    if (defaultSettings.syncSettings.timezone == 'UTC') {
      final detectedTimezone = detectDeviceTimezone();
      final settingsWithTimezone = defaultSettings.copyWith(
        syncSettings: defaultSettings.syncSettings.copyWith(timezone: detectedTimezone),
      );
      _cachedSettings = settingsWithTimezone;
      await saveSettings(settingsWithTimezone);
      print('✅ Detected and set device timezone: $detectedTimezone');
      return settingsWithTimezone;
    }
    
    _cachedSettings = defaultSettings;
    await saveSettings(defaultSettings);
    return defaultSettings;
  }

  // Save settings (both local and remote)
  static Future<void> saveSettings(SettingsModel settings) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Update cache
    _cachedSettings = settings;

    // Save locally
    await _saveLocalSettings(settings);

    // Save to Firestore
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .set(settings.toMap());
    } catch (e) {
      print('Error saving settings to Firestore: $e');
      // Don't throw error, local save succeeded
    }
  }

  // Update specific settings section
  static Future<void> updateReminderSettings(ReminderSettings reminderSettings) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      reminderSettings: reminderSettings,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  static Future<void> updateSyncSettings(SyncSettings syncSettings) async {
    final currentSettings = await getSettings();
    
    // Check if timezone changed
    final timezoneChanged = currentSettings.syncSettings.timezone != syncSettings.timezone;
    
    final updatedSettings = currentSettings.copyWith(
      syncSettings: syncSettings,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
    
    // If timezone changed, trigger re-scheduling of all reminders
    if (timezoneChanged) {
      print('🔄 Timezone changed from ${currentSettings.syncSettings.timezone} to ${syncSettings.timezone}');
      // Clear cache to ensure fresh settings are loaded
      _cachedSettings = null;
      // Import here to avoid circular dependency
      // Note: This will be handled in the background task service when it next runs
    }
  }

  static Future<void> updateAppearanceSettings(AppearanceSettings appearance) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      appearance: appearance,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  static Future<void> updateVoiceSettings(VoiceSettings voiceSettings) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      voiceSettings: voiceSettings,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  static Future<void> updateEmailSettings(EmailSettings emailSettings) async {
    final currentSettings = await getSettings();
    final updatedSettings = currentSettings.copyWith(
      emailSettings: emailSettings,
      updatedAt: DateTime.now(),
    );
    await saveSettings(updatedSettings);
  }

  // Get settings stream for real-time updates
  static Stream<SettingsModel> getSettingsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(SettingsModel.defaultSettings(''));

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('user_settings')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final settings = SettingsModel.fromMap(snapshot.data()!, snapshot.id);
        _cachedSettings = settings;
        _saveLocalSettings(settings); // Update local cache
        return settings;
      }
      return SettingsModel.defaultSettings(user.uid);
    });
  }

  // Local storage methods
  static Future<SettingsModel?> _getLocalSettings(String userId) async {
    if (_prefs == null) return null;

    try {
      final reminderSettingsJson = _prefs!.getString('reminder_settings_$userId');
      final syncSettingsJson = _prefs!.getString('sync_settings_$userId');
      final appearanceJson = _prefs!.getString('appearance_$userId');
      final voiceSettingsJson = _prefs!.getString('voice_settings_$userId');
      final emailSettingsJson = _prefs!.getString('email_settings_$userId');

      if (reminderSettingsJson == null) return null;

      return SettingsModel(
        userId: userId,
        reminderSettings: ReminderSettings.fromMap(
          Map<String, dynamic>.from(
            reminderSettingsJson.split(',').asMap().map(
              (i, v) => MapEntry(v.split(':')[0], v.split(':')[1]),
            ),
          ),
        ),
        syncSettings: SyncSettings.fromMap(
          Map<String, dynamic>.from(
            syncSettingsJson?.split(',').asMap().map(
              (i, v) => MapEntry(v.split(':')[0], v.split(':')[1]),
            ) ?? {},
          ),
        ),
        appearance: AppearanceSettings.fromMap(
          Map<String, dynamic>.from(
            appearanceJson?.split(',').asMap().map(
              (i, v) => MapEntry(v.split(':')[0], v.split(':')[1]),
            ) ?? {},
          ),
        ),
        voiceSettings: VoiceSettings.fromMap(
          Map<String, dynamic>.from(
            voiceSettingsJson?.split(',').asMap().map(
              (i, v) => MapEntry(v.split(':')[0], v.split(':')[1]),
            ) ?? {},
          ),
        ),
        emailSettings: EmailSettings.fromMap(
          Map<String, dynamic>.from(
            emailSettingsJson?.split(',').asMap().map(
              (i, v) => MapEntry(v.split(':')[0], v.split(':')[1]),
            ) ?? {},
          ),
        ),
        calendarSettings: CalendarSettings.defaultSettings(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error loading local settings: $e');
      return null;
    }
  }

  static Future<void> _saveLocalSettings(SettingsModel settings) async {
    if (_prefs == null) return;

    try {
      // Convert to simple string format for SharedPreferences
      final reminderMap = settings.reminderSettings.toMap();
      final syncMap = settings.syncSettings.toMap();
      final appearanceMap = settings.appearance.toMap();
      final voiceMap = settings.voiceSettings.toMap();
      final emailMap = settings.emailSettings.toMap();

      await _prefs!.setString(
        'reminder_settings_${settings.userId}',
        reminderMap.entries.map((e) => '${e.key}:${e.value}').join(','),
      );
      await _prefs!.setString(
        'sync_settings_${settings.userId}',
        syncMap.entries.map((e) => '${e.key}:${e.value}').join(','),
      );
      await _prefs!.setString(
        'appearance_${settings.userId}',
        appearanceMap.entries.map((e) => '${e.key}:${e.value}').join(','),
      );
      await _prefs!.setString(
        'voice_settings_${settings.userId}',
        voiceMap.entries.map((e) => '${e.key}:${e.value}').join(','),
      );
      await _prefs!.setString(
        'email_settings_${settings.userId}',
        emailMap.entries.map((e) => '${e.key}:${e.value}').join(','),
      );
    } catch (e) {
      print('Error saving local settings: $e');
    }
  }

  // Clear all settings
  static Future<void> clearSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _cachedSettings = null;

    // Clear local storage
    if (_prefs != null) {
      await _prefs!.remove('reminder_settings_${user.uid}');
      await _prefs!.remove('sync_settings_${user.uid}');
      await _prefs!.remove('appearance_${user.uid}');
      await _prefs!.remove('voice_settings_${user.uid}');
      await _prefs!.remove('email_settings_${user.uid}');
    }

    // Clear from Firestore
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('user_settings')
          .delete();
    } catch (e) {
      print('Error clearing settings from Firestore: $e');
    }
  }

  // Get available notification sounds
  static List<String> getAvailableNotificationSounds() {
    return [
      'soft_chime.mp3',
      'gentle_bell.mp3',
      'digital_beep.mp3',
      'classic_alarm.mp3',
      'nature_sound.mp3',
      'default.mp3',
    ];
  }

  // Get available themes
  static List<String> getAvailableThemes() {
    return ['light', 'dark', 'system'];
  }

  // Get available font sizes
  static List<String> getAvailableFontSizes() {
    return ['small', 'medium', 'large'];
  }

  // Get available sync frequencies
  static List<String> getAvailableSyncFrequencies() {
    return ['15min', '30min', '1hr', '2hr'];
  }

  // Get available voice types
  static List<String> getAvailableVoiceTypes() {
    return ['male', 'female', 'system'];
  }

  // Get available languages
  static List<String> getAvailableLanguages() {
    return [
      'en-US',
      'en-GB',
      'es-ES',
      'fr-FR',
      'de-DE',
      'it-IT',
      'pt-BR',
      'ru-RU',
      'ja-JP',
      'ko-KR',
      'zh-CN',
    ];
  }

  // Clear all local data
  static Future<void> clearAllData() async {
    try {
      if (_prefs != null) {
        await _prefs!.clear();
      }
      _cachedSettings = null;
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }
}
