import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/api_keys.dart';
import '../models/reminder_model.dart';
import 'reminder_service.dart';

class Holiday {
  final String name;
  final DateTime date;
  final String country;

  Holiday({required this.name, required this.date, required this.country});
}

class HolidayService {
  static const _baseUrl = 'https://calendarific.com/api/v2/holidays';
  static const int _defaultWindowDays = 90;

  // Fetch holidays for given country and year/month
  static Future<List<Holiday>> fetchHolidays({
    required String country,
    int? year,
    int? month,
  }) async {
    final now = DateTime.now();
    final query = {
      'api_key': ApiKeys.calendarific,
      'country': country,
      'year': (year ?? now.year).toString(),
    };
    if (month != null) query['month'] = month.toString();

    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Calendarific request failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responseData = body['response']?['holidays'] as List<dynamic>? ?? [];

    return responseData.map((raw) {
      final dateInfo = raw['date']['iso'] as String;
      return Holiday(
        name: raw['name'] ?? 'Holiday',
        date: DateTime.parse(dateInfo),
        country: country.toUpperCase(),
      );
    }).toList();
  }

  // Get upcoming holidays within the next window (default 90 days)
  static Future<List<Holiday>> getUpcomingHolidays({
    String country = 'US',
    int daysAhead = _defaultWindowDays,
    int limit = 5,
  }) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final holidays = await fetchHolidays(country: country, year: now.year);

    final upcoming = holidays
        .where((h) => h.date.isAfter(now) && h.date.isBefore(endDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (limit < upcoming.length) {
      return upcoming.sublist(0, limit);
    }
    return upcoming;
  }

  // Create reminders for holidays in the next [daysAhead]
  static Future<int> syncUpcomingHolidays({
    required String country,
    int daysAhead = 60,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));

    final holidays = await fetchHolidays(
      country: country,
      year: now.year,
    );

    int created = 0;
    for (final holiday in holidays) {
      if (holiday.date.isBefore(now) || holiday.date.isAfter(endDate)) continue;

      final externalId = 'calendarific-${holiday.country}-${holiday.date.toIso8601String()}-${holiday.name}';

      final reminder = ReminderModel(
        title: '${holiday.name} (${holiday.country})',
        dateTime: DateTime(holiday.date.year, holiday.date.month, holiday.date.day, 9, 0),
        repeat: 'No Repeat',
        snooze: '1 Hour',
        createdBy: user.uid,
        source: 'Holiday',
        externalId: externalId,
        metadata: {
          'country': holiday.country,
          'holiday': holiday.name,
          'api': 'calendarific',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Avoid duplicates by checking if a reminder already exists with the same externalId
      final existingQuery = await FirebaseFirestore.instance
          .collection('reminders')
          .where('externalId', isEqualTo: externalId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) continue;

      await ReminderService.saveReminder(reminder);
      created++;
    }

    return created;
  }
}

