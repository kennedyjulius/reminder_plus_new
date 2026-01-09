import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModel {
  final String? id;
  final String userId;
  final ReminderSettings reminderSettings;
  final SyncSettings syncSettings;
  final AppearanceSettings appearance;
  final VoiceSettings voiceSettings;
  final EmailSettings emailSettings;
  final CalendarSettings calendarSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  SettingsModel({
    this.id,
    required this.userId,
    required this.reminderSettings,
    required this.syncSettings,
    required this.appearance,
    required this.voiceSettings,
    required this.emailSettings,
    required this.calendarSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SettingsModel.defaultSettings(String userId) {
    return SettingsModel(
      userId: userId,
      reminderSettings: ReminderSettings.defaultSettings(),
      syncSettings: SyncSettings.defaultSettings(),
      appearance: AppearanceSettings.defaultSettings(),
      voiceSettings: VoiceSettings.defaultSettings(),
      emailSettings: EmailSettings.defaultSettings(),
      calendarSettings: CalendarSettings.defaultSettings(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reminderSettings': reminderSettings.toMap(),
      'syncSettings': syncSettings.toMap(),
      'appearance': appearance.toMap(),
      'voiceSettings': voiceSettings.toMap(),
      'emailSettings': emailSettings.toMap(),
      'calendarSettings': calendarSettings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map, String id) {
    return SettingsModel(
      id: id,
      userId: map['userId'] ?? '',
      reminderSettings: ReminderSettings.fromMap(map['reminderSettings'] ?? {}),
      syncSettings: SyncSettings.fromMap(map['syncSettings'] ?? {}),
      appearance: AppearanceSettings.fromMap(map['appearance'] ?? {}),
      voiceSettings: VoiceSettings.fromMap(map['voiceSettings'] ?? {}),
      emailSettings: EmailSettings.fromMap(map['emailSettings'] ?? {}),
      calendarSettings: CalendarSettings.fromMap(map['calendarSettings'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  SettingsModel copyWith({
    String? id,
    String? userId,
    ReminderSettings? reminderSettings,
    SyncSettings? syncSettings,
    AppearanceSettings? appearance,
    VoiceSettings? voiceSettings,
    EmailSettings? emailSettings,
    CalendarSettings? calendarSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reminderSettings: reminderSettings ?? this.reminderSettings,
      syncSettings: syncSettings ?? this.syncSettings,
      appearance: appearance ?? this.appearance,
      voiceSettings: voiceSettings ?? this.voiceSettings,
      emailSettings: emailSettings ?? this.emailSettings,
      calendarSettings: calendarSettings ?? this.calendarSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReminderSettings {
  final String defaultTime;
  final int snoozeDuration; // in minutes
  final String notificationSound;
  final bool vibration;
  final bool smartNotifications;

  ReminderSettings({
    required this.defaultTime,
    required this.snoozeDuration,
    required this.notificationSound,
    required this.vibration,
    required this.smartNotifications,
  });

  factory ReminderSettings.defaultSettings() {
    return ReminderSettings(
      defaultTime: '09:00',
      snoozeDuration: 10,
      notificationSound: 'soft_chime.mp3',
      vibration: true,
      smartNotifications: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultTime': defaultTime,
      'snoozeDuration': snoozeDuration,
      'notificationSound': notificationSound,
      'vibration': vibration,
      'smartNotifications': smartNotifications,
    };
  }

  factory ReminderSettings.fromMap(Map<String, dynamic> map) {
    return ReminderSettings(
      defaultTime: map['defaultTime'] ?? '09:00',
      snoozeDuration: map['snoozeDuration'] ?? 10,
      notificationSound: map['notificationSound'] ?? 'soft_chime.mp3',
      vibration: map['vibration'] ?? true,
      smartNotifications: map['smartNotifications'] ?? true,
    );
  }

  ReminderSettings copyWith({
    String? defaultTime,
    int? snoozeDuration,
    String? notificationSound,
    bool? vibration,
    bool? smartNotifications,
  }) {
    return ReminderSettings(
      defaultTime: defaultTime ?? this.defaultTime,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      notificationSound: notificationSound ?? this.notificationSound,
      vibration: vibration ?? this.vibration,
      smartNotifications: smartNotifications ?? this.smartNotifications,
    );
  }
}

class SyncSettings {
  final bool backgroundSync;
  final String syncFrequency; // '15min', '30min', '1hr', '2hr'
  final bool wifiOnly;
  final bool autoSync;
  final String timezone; // Timezone identifier (e.g., 'America/New_York', 'Europe/London')

  SyncSettings({
    required this.backgroundSync,
    required this.syncFrequency,
    required this.wifiOnly,
    required this.autoSync,
    required this.timezone,
  });

  factory SyncSettings.defaultSettings() {
    return SyncSettings(
      backgroundSync: true,
      syncFrequency: '15min',
      wifiOnly: false,
      autoSync: true,
      timezone: 'UTC', // Default to UTC, will be set by user
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'backgroundSync': backgroundSync,
      'syncFrequency': syncFrequency,
      'wifiOnly': wifiOnly,
      'autoSync': autoSync,
      'timezone': timezone,
    };
  }

  factory SyncSettings.fromMap(Map<String, dynamic> map) {
    return SyncSettings(
      backgroundSync: map['backgroundSync'] ?? true,
      syncFrequency: map['syncFrequency'] ?? '15min',
      wifiOnly: map['wifiOnly'] ?? false,
      autoSync: map['autoSync'] ?? true,
      timezone: map['timezone'] ?? 'UTC',
    );
  }

  SyncSettings copyWith({
    bool? backgroundSync,
    String? syncFrequency,
    bool? wifiOnly,
    bool? autoSync,
    String? timezone,
  }) {
    return SyncSettings(
      backgroundSync: backgroundSync ?? this.backgroundSync,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      autoSync: autoSync ?? this.autoSync,
      timezone: timezone ?? this.timezone,
    );
  }

  int get syncFrequencyMinutes {
    switch (syncFrequency) {
      case '15min':
        return 15;
      case '30min':
        return 30;
      case '1hr':
        return 60;
      case '2hr':
        return 120;
      default:
        return 15;
    }
  }
}

class AppearanceSettings {
  final String theme; // 'light', 'dark', 'system'
  final String fontSize; // 'small', 'medium', 'large'
  final String primaryColor;
  final bool useGradient;

  AppearanceSettings({
    required this.theme,
    required this.fontSize,
    required this.primaryColor,
    required this.useGradient,
  });

  factory AppearanceSettings.defaultSettings() {
    return AppearanceSettings(
      theme: 'dark',
      fontSize: 'medium',
      primaryColor: '#8A2BE2',
      useGradient: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'fontSize': fontSize,
      'primaryColor': primaryColor,
      'useGradient': useGradient,
    };
  }

  factory AppearanceSettings.fromMap(Map<String, dynamic> map) {
    return AppearanceSettings(
      theme: map['theme'] ?? 'dark',
      fontSize: map['fontSize'] ?? 'medium',
      primaryColor: map['primaryColor'] ?? '#8A2BE2',
      useGradient: map['useGradient'] ?? true,
    );
  }

  AppearanceSettings copyWith({
    String? theme,
    String? fontSize,
    String? primaryColor,
    bool? useGradient,
  }) {
    return AppearanceSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      primaryColor: primaryColor ?? this.primaryColor,
      useGradient: useGradient ?? this.useGradient,
    );
  }
}

class VoiceSettings {
  final bool enabled;
  final String language;
  final String voiceType; // 'male', 'female', 'system'
  final double speechRate;
  final bool autoListen;

  VoiceSettings({
    required this.enabled,
    required this.language,
    required this.voiceType,
    required this.speechRate,
    required this.autoListen,
  });

  factory VoiceSettings.defaultSettings() {
    return VoiceSettings(
      enabled: true,
      language: 'en-US',
      voiceType: 'female',
      speechRate: 0.5,
      autoListen: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'language': language,
      'voiceType': voiceType,
      'speechRate': speechRate,
      'autoListen': autoListen,
    };
  }

  factory VoiceSettings.fromMap(Map<String, dynamic> map) {
    return VoiceSettings(
      enabled: map['enabled'] ?? true,
      language: map['language'] ?? 'en-US',
      voiceType: map['voiceType'] ?? 'female',
      speechRate: (map['speechRate'] ?? 0.5).toDouble(),
      autoListen: map['autoListen'] ?? false,
    );
  }

  VoiceSettings copyWith({
    bool? enabled,
    String? language,
    String? voiceType,
    double? speechRate,
    bool? autoListen,
  }) {
    return VoiceSettings(
      enabled: enabled ?? this.enabled,
      language: language ?? this.language,
      voiceType: voiceType ?? this.voiceType,
      speechRate: speechRate ?? this.speechRate,
      autoListen: autoListen ?? this.autoListen,
    );
  }
}

class EmailSettings {
  final bool gmailConnected;
  final bool outlookConnected;
  final bool emailParsing;
  final String syncInterval; // '15min', '30min', '1hr'
  final bool autoCreateReminders;

  EmailSettings({
    required this.gmailConnected,
    required this.outlookConnected,
    required this.emailParsing,
    required this.syncInterval,
    required this.autoCreateReminders,
  });

  factory EmailSettings.defaultSettings() {
    return EmailSettings(
      gmailConnected: false,
      outlookConnected: false,
      emailParsing: false,
      syncInterval: '30min',
      autoCreateReminders: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gmailConnected': gmailConnected,
      'outlookConnected': outlookConnected,
      'emailParsing': emailParsing,
      'syncInterval': syncInterval,
      'autoCreateReminders': autoCreateReminders,
    };
  }

  factory EmailSettings.fromMap(Map<String, dynamic> map) {
    return EmailSettings(
      gmailConnected: map['gmailConnected'] ?? false,
      outlookConnected: map['outlookConnected'] ?? false,
      emailParsing: map['emailParsing'] ?? false,
      syncInterval: map['syncInterval'] ?? '30min',
      autoCreateReminders: map['autoCreateReminders'] ?? true,
    );
  }

  EmailSettings copyWith({
    bool? gmailConnected,
    bool? outlookConnected,
    bool? emailParsing,
    String? syncInterval,
    bool? autoCreateReminders,
  }) {
    return EmailSettings(
      gmailConnected: gmailConnected ?? this.gmailConnected,
      outlookConnected: outlookConnected ?? this.outlookConnected,
      emailParsing: emailParsing ?? this.emailParsing,
      syncInterval: syncInterval ?? this.syncInterval,
      autoCreateReminders: autoCreateReminders ?? this.autoCreateReminders,
    );
  }
}

class CalendarSettings {
  final bool googleCalendarConnected;
  final bool calendlyConnected;
  final bool autoSync;
  final String syncFrequency; // '15min', '30min', '1hr', '2hr'
  final bool createRemindersForEvents;
  final bool includeAllDayEvents;
  final int reminderTimeBeforeEvent; // in minutes
  final String? googleCalendarToken;
  final String? calendlyToken;

  CalendarSettings({
    required this.googleCalendarConnected,
    required this.calendlyConnected,
    required this.autoSync,
    required this.syncFrequency,
    required this.createRemindersForEvents,
    required this.includeAllDayEvents,
    required this.reminderTimeBeforeEvent,
    this.googleCalendarToken,
    this.calendlyToken,
  });

  factory CalendarSettings.defaultSettings() {
    return CalendarSettings(
      googleCalendarConnected: false,
      calendlyConnected: false,
      autoSync: true,
      syncFrequency: '30min',
      createRemindersForEvents: true,
      includeAllDayEvents: false,
      reminderTimeBeforeEvent: 15, // 15 minutes before event
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'googleCalendarConnected': googleCalendarConnected,
      'calendlyConnected': calendlyConnected,
      'autoSync': autoSync,
      'syncFrequency': syncFrequency,
      'createRemindersForEvents': createRemindersForEvents,
      'includeAllDayEvents': includeAllDayEvents,
      'reminderTimeBeforeEvent': reminderTimeBeforeEvent,
      'googleCalendarToken': googleCalendarToken,
      'calendlyToken': calendlyToken,
    };
  }

  factory CalendarSettings.fromMap(Map<String, dynamic> map) {
    return CalendarSettings(
      googleCalendarConnected: map['googleCalendarConnected'] ?? false,
      calendlyConnected: map['calendlyConnected'] ?? false,
      autoSync: map['autoSync'] ?? true,
      syncFrequency: map['syncFrequency'] ?? '30min',
      createRemindersForEvents: map['createRemindersForEvents'] ?? true,
      includeAllDayEvents: map['includeAllDayEvents'] ?? false,
      reminderTimeBeforeEvent: map['reminderTimeBeforeEvent'] ?? 15,
      googleCalendarToken: map['googleCalendarToken'],
      calendlyToken: map['calendlyToken'],
    );
  }

  CalendarSettings copyWith({
    bool? googleCalendarConnected,
    bool? calendlyConnected,
    bool? autoSync,
    String? syncFrequency,
    bool? createRemindersForEvents,
    bool? includeAllDayEvents,
    int? reminderTimeBeforeEvent,
    String? googleCalendarToken,
    String? calendlyToken,
  }) {
    return CalendarSettings(
      googleCalendarConnected: googleCalendarConnected ?? this.googleCalendarConnected,
      calendlyConnected: calendlyConnected ?? this.calendlyConnected,
      autoSync: autoSync ?? this.autoSync,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      createRemindersForEvents: createRemindersForEvents ?? this.createRemindersForEvents,
      includeAllDayEvents: includeAllDayEvents ?? this.includeAllDayEvents,
      reminderTimeBeforeEvent: reminderTimeBeforeEvent ?? this.reminderTimeBeforeEvent,
      googleCalendarToken: googleCalendarToken ?? this.googleCalendarToken,
      calendlyToken: calendlyToken ?? this.calendlyToken,
    );
  }

  int get syncFrequencyMinutes {
    switch (syncFrequency) {
      case '15min':
        return 15;
      case '30min':
        return 30;
      case '1hr':
        return 60;
      case '2hr':
        return 120;
      default:
        return 30;
    }
  }
}
