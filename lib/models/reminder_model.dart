import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String? id;
  final String title;
  final DateTime dateTime;
  final String repeat;
  final String snooze;
  final String createdBy;
  final String source; // 'google', 'calendly', 'voice', 'email', 'ocr', 'manual'
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notificationSound; // Custom sound for this reminder
  final String? externalId; // ID from external service (Google Calendar event ID, Calendly event ID, etc.)
  final Map<String, dynamic>? metadata; // Additional data from external services
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderModel({
    this.id,
    required this.title,
    required this.dateTime,
    required this.repeat,
    required this.snooze,
    required this.createdBy,
    required this.source,
    this.isCompleted = false,
    this.completedAt,
    this.notificationSound,
    this.externalId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'repeat': repeat,
      'snooze': snooze,
      'createdBy': createdBy,
      'source': source,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notificationSound': notificationSound,
      'externalId': externalId,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create from Firestore Document
  factory ReminderModel.fromMap(Map<String, dynamic> map, String id) {
    return ReminderModel(
      id: id,
      title: map['title'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      repeat: map['repeat'] ?? 'No Repeat',
      snooze: map['snooze'] ?? '5 Min',
      createdBy: map['createdBy'] ?? '',
      source: map['source'] ?? 'manual',
      isCompleted: map['isCompleted'] ?? false,
      completedAt: map['completedAt'] != null ? (map['completedAt'] as Timestamp).toDate() : null,
      notificationSound: map['notificationSound'],
      externalId: map['externalId'],
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Create a copy with updated fields
  ReminderModel copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? repeat,
    String? snooze,
    String? createdBy,
    String? source,
    bool? isCompleted,
    DateTime? completedAt,
    String? notificationSound,
    String? externalId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      repeat: repeat ?? this.repeat,
      snooze: snooze ?? this.snooze,
      createdBy: createdBy ?? this.createdBy,
      source: source ?? this.source,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notificationSound: notificationSound ?? this.notificationSound,
      externalId: externalId ?? this.externalId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get repeat intervals as list
  static List<String> get repeatOptions => [
    'No Repeat',
    'Every Hour',
    'Every Day',
    'Every Week',
    'Every Month',
    'Every Monday',
    'Every Tuesday',
    'Every Wednesday',
    'Every Thursday',
    'Every Friday',
    'Every Saturday',
    'Every Sunday',
    'Custom Interval',
  ];

  // Get snooze options as list
  static List<String> get snoozeOptions => [
    '5 Min',
    '10 Min',
    '15 Min',
    '30 Min',
    '1 Hour',
    '2 Hours',
    'Tomorrow',
    'Custom',
  ];

  // Parse repeat interval to minutes
  int get repeatIntervalMinutes {
    switch (repeat) {
      case 'Every Hour':
        return 60;
      case 'Every Day':
        return 1440; // 24 * 60
      case 'Every Week':
        return 10080; // 7 * 24 * 60
      case 'Every Month':
        return 43200; // 30 * 24 * 60 (approximate)
      case 'Every Monday':
      case 'Every Tuesday':
      case 'Every Wednesday':
      case 'Every Thursday':
      case 'Every Friday':
      case 'Every Saturday':
      case 'Every Sunday':
        return 10080; // 7 * 24 * 60 (weekly)
      default:
        // Handle custom intervals like "Every 10 Min", "Every 2 Hour", etc.
        if (repeat.startsWith('Every ')) {
          final parts = repeat.substring(6).split(' '); // Remove "Every "
          if (parts.length >= 2) {
            final number = int.tryParse(parts[0]);
            final unit = parts[1].toLowerCase();
            
            if (number != null) {
              if (unit.startsWith('min')) {
                return number;
              } else if (unit.startsWith('hour')) {
                return number * 60;
              } else if (unit.startsWith('day')) {
                return number * 1440; // 24 * 60
              } else if (unit.startsWith('week')) {
                return number * 10080; // 7 * 24 * 60
              } else if (unit.startsWith('month')) {
                return number * 43200; // 30 * 24 * 60
              }
            }
          }
        }
        return 0;
    }
  }

  // Parse snooze duration to minutes
  int get snoozeDurationMinutes {
    switch (snooze) {
      case '5 Min':
        return 5;
      case '10 Min':
        return 10;
      case '15 Min':
        return 15;
      case '30 Min':
        return 30;
      case '1 Hour':
        return 60;
      case '2 Hours':
        return 120;
      case 'Tomorrow':
        return 1440; // 24 * 60
      default:
        return 5; // Default to 5 minutes
    }
  }

  // Check if reminder is due
  bool get isDue => DateTime.now().isAfter(dateTime) && !isCompleted;

  // Get next occurrence for repeating reminders
  DateTime? get nextOccurrence {
    if (repeat == 'No Repeat') return null;
    
    final now = DateTime.now();
    final intervalMinutes = repeatIntervalMinutes;
    
    if (intervalMinutes == 0) return null;
    
    DateTime next = dateTime;
    while (next.isBefore(now)) {
      next = next.add(Duration(minutes: intervalMinutes));
    }
    
    return next;
  }

  @override
  String toString() {
    return 'ReminderModel(id: $id, title: $title, dateTime: $dateTime, repeat: $repeat, snooze: $snooze, source: $source)';
  }
}
