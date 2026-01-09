import 'package:flutter/material.dart';

class VoiceDateParser {
  // Parse voice input to extract date, time, repeat, and snooze options
  static Map<String, dynamic> parseDateTime(String text) {
    final lowerText = text.toLowerCase();
    
    DateTime? parsedDate;
    TimeOfDay? parsedTime;
    String extractedTitle = text;
    String repeatOption = 'No Repeat';
    String snoozeOption = '5 Min';
    
    // Extract time first (e.g., "11:00 am", "11 am", "2:30 pm")
    parsedTime = _extractTime(lowerText);
    
    // Extract date (e.g., "sunday 25th october", "october 25", "tomorrow", "next monday")
    parsedDate = _extractDate(lowerText);
    
    // Extract repeat options
    repeatOption = _extractRepeatOption(lowerText);
    
    // Extract snooze options
    snoozeOption = _extractSnoozeOption(lowerText);
    
    // Extract title by removing date/time/repeat/snooze phrases
    extractedTitle = _extractTitle(text, lowerText);
    
    // If no date found, default to tomorrow
    if (parsedDate == null) {
      parsedDate = DateTime.now().add(const Duration(days: 1));
    }
    
    // If no time found, default to 9:00 AM
    if (parsedTime == null) {
      parsedTime = const TimeOfDay(hour: 9, minute: 0);
    }
    
    // Combine date and time
    final dateTime = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedTime.hour,
      parsedTime.minute,
    );
    
    return {
      'title': extractedTitle.trim(),
      'dateTime': dateTime,
      'date': DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      'time': parsedTime,
      'repeat': repeatOption,
      'snooze': snoozeOption,
      'hasExplicitDate': parsedDate != null,
      'hasExplicitTime': parsedTime != null,
      'hasExplicitRepeat': repeatOption != 'No Repeat',
      'hasExplicitSnooze': snoozeOption != '5 Min',
    };
  }
  
  // Extract time from text
  static TimeOfDay? _extractTime(String text) {
    final lowerText = text.toLowerCase();
    
    // Normalized helpers for AM/PM variants like "p.m.", "pm", "p m"
    // We'll detect both am/pm and a.m./p.m. variants - capture AM/PM as a group
    final ampmWord = r'((?:a\.?\s*m\.?)|(?:p\.?\s*m\.?))';
    final ampmCompact = r'((am)|(pm))'; // used when we explicitly lower/strip

    // Pattern 1: "11:00 am", "2:30 pm", "11:00 a.m.", "2:30 p.m.", "5pm", "5:00pm"
    // More flexible pattern that allows optional spaces and colons
    final timePattern1 = RegExp(r'(?:at\s+)?(\d{1,2}):?(\d{2})?\s*' + ampmWord, caseSensitive: false);
    final match1 = timePattern1.firstMatch(text);
    
    if (match1 != null) {
      int hour = int.parse(match1.group(1)!);
      final minuteStr = match1.group(2);
      final minute = minuteStr != null && minuteStr.isNotEmpty ? int.parse(minuteStr) : 0;
      
      // Extract the AM/PM period - group 3 contains the full AM/PM match
      final ampmMatch = match1.group(3);
      final fullMatch = match1.group(0)!.toLowerCase();
      
      // Determine if PM: check if the AM/PM group contains 'p' (but not 'a')
      // Or check the full match string for 'pm' or 'p.m.'
      bool isPM = false;
      if (ampmMatch != null) {
        final ampmLower = ampmMatch.toLowerCase();
        isPM = ampmLower.contains('p') && !ampmLower.contains('a');
      } else {
        // Fallback: check the full match string
        isPM = fullMatch.contains('pm') || fullMatch.contains('p.m.') || 
               (fullMatch.contains('p') && !fullMatch.contains('am') && !fullMatch.contains('a.m.'));
      }
      
      // Apply AM/PM conversion
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      print('🕐 Extracted time: $hour:${minute.toString().padLeft(2, '0')} (from: "$text", isPM: $isPM, ampmMatch: "$ampmMatch")');
      return TimeOfDay(hour: hour, minute: minute);
    }
    
    // Pattern 2: "11 am", "2 pm", "11 a.m.", "2 p.m.", "5pm" (without colon/minutes)
    final timePattern2 = RegExp(r'(?:at\s+)?(\d{1,2})\s*' + ampmWord, caseSensitive: false);
    final match2 = timePattern2.firstMatch(text);
    
    if (match2 != null) {
      int hour = int.parse(match2.group(1)!);
      
      // Extract the AM/PM period - group 2 contains the full AM/PM match
      final ampmMatch = match2.group(2);
      final fullMatch = match2.group(0)!.toLowerCase();
      
      // Determine if PM
      bool isPM = false;
      if (ampmMatch != null) {
        final ampmLower = ampmMatch.toLowerCase();
        isPM = ampmLower.contains('p') && !ampmLower.contains('a');
      } else {
        // Fallback: check the full match string
        isPM = fullMatch.contains('pm') || fullMatch.contains('p.m.') || 
               (fullMatch.contains('p') && !fullMatch.contains('am') && !fullMatch.contains('a.m.'));
      }
      
      // Apply AM/PM conversion
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      print('🕐 Extracted time: $hour:00 (from: "$text", isPM: $isPM, ampmMatch: "$ampmMatch")');
      return TimeOfDay(hour: hour, minute: 0);
    }
    
    // Pattern 3: "11:00" (24-hour format)
    final timePattern3 = RegExp(r'(?:at\s+)?(\d{1,2}):(\d{2})(?!\s*[ap]m)');
    final match3 = timePattern3.firstMatch(text);
    
    if (match3 != null) {
      final hour = int.parse(match3.group(1)!);
      final minute = int.parse(match3.group(2)!);
      
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    // Natural language fallbacks: "in the evening/afternoon/morning", "tonight", "noon", "midnight"
    if (RegExp(r'\bnoon\b').hasMatch(text)) {
      return const TimeOfDay(hour: 12, minute: 0);
    }
    if (RegExp(r'\bmidnight\b').hasMatch(text)) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    if (RegExp(r'\btonight\b').hasMatch(text)) {
      return const TimeOfDay(hour: 20, minute: 0); // sensible default for "tonight"
    }
    if (RegExp(r'\bin the (evening|eve)\b').hasMatch(text)) {
      return const TimeOfDay(hour: 18, minute: 0);
    }
    if (RegExp(r'\bin the afternoon\b').hasMatch(text)) {
      return const TimeOfDay(hour: 15, minute: 0);
    }
    if (RegExp(r'\bin the morning\b').hasMatch(text)) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    
    return null;
  }
  
  // Extract date from text
  static DateTime? _extractDate(String text) {
    final now = DateTime.now();
    
    // Check for "today"
    if (text.contains('today')) {
      return DateTime(now.year, now.month, now.day);
    }
    
    // Check for "tomorrow"
    if (text.contains('tomorrow')) {
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    }
    
    // Check for day after tomorrow
    if (text.contains('day after tomorrow')) {
      final dayAfter = now.add(const Duration(days: 2));
      return DateTime(dayAfter.year, dayAfter.month, dayAfter.day);
    }
    
    // Check for holidays and special dates
    final holidayDate = _extractHolidayDate(text, now);
    if (holidayDate != null) {
      return holidayDate;
    }
    
    // Check for specific weekday (e.g., "sunday", "next monday")
    final weekdayDate = _extractWeekday(text);
    if (weekdayDate != null) {
      // Now check if there's a specific date mentioned (e.g., "25th")
      final specificDate = _extractSpecificDate(text, weekdayDate.month);
      if (specificDate != null) {
        return specificDate;
      }
      return weekdayDate;
    }
    
    // Check for specific date patterns (e.g., "25th october", "october 25", "25/10")
    final specificDate = _extractSpecificDate(text, now.month);
    if (specificDate != null) {
      return specificDate;
    }
    
    // Check for relative dates (e.g., "in 3 days", "next week")
    final relativeDate = _extractRelativeDate(text);
    if (relativeDate != null) {
      return relativeDate;
    }
    
    return null;
  }
  
  // Extract holiday dates (e.g., "Christmas", "New Year", "Easter")
  static DateTime? _extractHolidayDate(String text, DateTime now) {
    // Fixed date holidays
    final fixedHolidays = {
      'christmas': [12, 25],
      'christmas day': [12, 25],
      'christmas eve': [12, 24],
      'new year': [1, 1],
      'new year\'s day': [1, 1],
      'new year\'s eve': [12, 31],
      'new years': [1, 1],
      'new years day': [1, 1],
      'valentine\'s day': [2, 14],
      'valentines day': [2, 14],
      'valentine': [2, 14],
      'halloween': [10, 31],
      'independence day': [7, 4],
      'july fourth': [7, 4],
      'july 4th': [7, 4],
    };
    
    for (final entry in fixedHolidays.entries) {
      if (text.contains(entry.key)) {
        int month = entry.value[0];
        int day = entry.value[1];
        int year = now.year;
        
        final targetDate = DateTime(year, month, day);
        
        // If the date has passed this year, schedule for next year
        if (targetDate.isBefore(now.subtract(const Duration(days: 1)))) {
          year++;
        }
        
        return DateTime(year, month, day);
      }
    }
    
    // Handle calculated holidays
    if (text.contains('easter')) {
      final easterDate = _getEasterDate(now.year);
      if (easterDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getEasterDate(now.year + 1);
      }
      return easterDate;
    }
    
    if (text.contains('thanksgiving')) {
      final thanksgivingDate = _getThanksgivingDate(now.year);
      if (thanksgivingDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getThanksgivingDate(now.year + 1);
      }
      return thanksgivingDate;
    }
    
    if (text.contains('labor day')) {
      final laborDayDate = _getLaborDayDate(now.year);
      if (laborDayDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getLaborDayDate(now.year + 1);
      }
      return laborDayDate;
    }
    
    if (text.contains('memorial day')) {
      final memorialDayDate = _getMemorialDayDate(now.year);
      if (memorialDayDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getMemorialDayDate(now.year + 1);
      }
      return memorialDayDate;
    }
    
    if (text.contains('mother') && text.contains('day')) {
      final mothersDayDate = _getMothersDayDate(now.year);
      if (mothersDayDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getMothersDayDate(now.year + 1);
      }
      return mothersDayDate;
    }
    
    if (text.contains('father') && text.contains('day')) {
      final fathersDayDate = _getFathersDayDate(now.year);
      if (fathersDayDate.isBefore(now.subtract(const Duration(days: 1)))) {
        return _getFathersDayDate(now.year + 1);
      }
      return fathersDayDate;
    }
    
    return null;
  }
  
  // Calculate Easter date (using simplified algorithm)
  static DateTime _getEasterDate(int year) {
    // Simplified Easter calculation (Meeus/Jones/Butcher algorithm)
    int a = year % 19;
    int b = year ~/ 100;
    int c = year % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int day = ((h + l - 7 * m + 114) % 31) + 1;
    
    return DateTime(year, month, day);
  }
  
  // Calculate Thanksgiving (4th Thursday of November)
  static DateTime _getThanksgivingDate(int year) {
    final nov1 = DateTime(year, 11, 1);
    final weekday = nov1.weekday;
    final daysToAdd = (4 - weekday + 7) % 7 + 21; // 4th Thursday
    return DateTime(year, 11, 1 + daysToAdd);
  }
  
  // Calculate Labor Day (1st Monday of September)
  static DateTime _getLaborDayDate(int year) {
    final sep1 = DateTime(year, 9, 1);
    final weekday = sep1.weekday;
    final daysToAdd = (1 - weekday + 7) % 7; // 1st Monday
    return DateTime(year, 9, 1 + daysToAdd);
  }
  
  // Calculate Memorial Day (last Monday of May)
  static DateTime _getMemorialDayDate(int year) {
    final may31 = DateTime(year, 5, 31);
    final weekday = may31.weekday;
    final daysToSubtract = (weekday - 1) % 7;
    return DateTime(year, 5, 31 - daysToSubtract);
  }
  
  // Calculate Mother's Day (2nd Sunday of May)
  static DateTime _getMothersDayDate(int year) {
    final may1 = DateTime(year, 5, 1);
    final weekday = may1.weekday;
    final daysToAdd = (7 - weekday + 7) % 7 + 7; // 2nd Sunday
    return DateTime(year, 5, 1 + daysToAdd);
  }
  
  // Calculate Father's Day (3rd Sunday of June)
  static DateTime _getFathersDayDate(int year) {
    final jun1 = DateTime(year, 6, 1);
    final weekday = jun1.weekday;
    final daysToAdd = (7 - weekday + 7) % 7 + 14; // 3rd Sunday
    return DateTime(year, 6, 1 + daysToAdd);
  }
  
  // Extract weekday from text
  static DateTime? _extractWeekday(String text) {
    final now = DateTime.now();
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    
    for (final entry in weekdays.entries) {
      if (text.contains(entry.key)) {
        final targetWeekday = entry.value;
        final currentWeekday = now.weekday;
        
        int daysToAdd = targetWeekday - currentWeekday;
        
        // If it's asking for "next monday" explicitly
        if (text.contains('next ${entry.key}')) {
          daysToAdd = daysToAdd <= 0 ? daysToAdd + 7 : daysToAdd + 7;
        } else {
          // If the target day is today or has passed this week, schedule for next week
          if (daysToAdd <= 0) {
            daysToAdd += 7;
          }
        }
        
        final targetDate = now.add(Duration(days: daysToAdd));
        return DateTime(targetDate.year, targetDate.month, targetDate.day);
      }
    }
    
    return null;
  }
  
  // Extract specific date (e.g., "25th october", "october 25")
  static DateTime? _extractSpecificDate(String text, int defaultMonth) {
    final now = DateTime.now();
    
    // Month names mapping
    final months = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    
    // Pattern: "25th october", "25 october"
    for (final entry in months.entries) {
      final pattern1 = RegExp(r'(\d{1,2})(?:st|nd|rd|th)?\s+' + entry.key, caseSensitive: false);
      final match1 = pattern1.firstMatch(text);
      
      if (match1 != null) {
        final day = int.parse(match1.group(1)!);
        final month = entry.value;
        
        // Determine the year
        int year = now.year;
        final targetDate = DateTime(year, month, day);
        
        // If the date has passed this year, schedule for next year
        if (targetDate.isBefore(now)) {
          year++;
        }
        
        return DateTime(year, month, day);
      }
      
      // Pattern: "october 25", "october 25th"
      final pattern2 = RegExp(entry.key + r'\s+(\d{1,2})(?:st|nd|rd|th)?', caseSensitive: false);
      final match2 = pattern2.firstMatch(text);
      
      if (match2 != null) {
        final day = int.parse(match2.group(1)!);
        final month = entry.value;
        
        // Determine the year
        int year = now.year;
        final targetDate = DateTime(year, month, day);
        
        // If the date has passed this year, schedule for next year
        if (targetDate.isBefore(now)) {
          year++;
        }
        
        return DateTime(year, month, day);
      }
    }
    
    // Pattern: "25/10", "25-10", "10/25"
    final datePattern = RegExp(r'(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?');
    final dateMatch = datePattern.firstMatch(text);
    
    if (dateMatch != null) {
      int day = int.parse(dateMatch.group(1)!);
      int month = int.parse(dateMatch.group(2)!);
      int year = dateMatch.group(3) != null 
          ? int.parse(dateMatch.group(3)!) 
          : now.year;
      
      // Handle 2-digit year
      if (year < 100) {
        year += 2000;
      }
      
      // Try to determine if it's DD/MM or MM/DD format
      // If day > 12, it must be DD/MM format
      if (day > 12) {
        // Swap
        final temp = day;
        day = month;
        month = temp;
      }
      
      try {
        final targetDate = DateTime(year, month, day);
        
        // If the date has passed this year, schedule for next year
        if (targetDate.isBefore(now) && dateMatch.group(3) == null) {
          year++;
          return DateTime(year, month, day);
        }
        
        return targetDate;
      } catch (e) {
        // Invalid date
        return null;
      }
    }
    
    return null;
  }
  
  // Extract relative date (e.g., "in 3 days", "next week")
  static DateTime? _extractRelativeDate(String text) {
    final now = DateTime.now();
    
    // Pattern: "in X days"
    final daysPattern = RegExp(r'in\s+(\d+)\s+days?');
    final daysMatch = daysPattern.firstMatch(text);
    
    if (daysMatch != null) {
      final days = int.parse(daysMatch.group(1)!);
      final targetDate = now.add(Duration(days: days));
      return DateTime(targetDate.year, targetDate.month, targetDate.day);
    }
    
    // Pattern: "in X weeks"
    final weeksPattern = RegExp(r'in\s+(\d+)\s+weeks?');
    final weeksMatch = weeksPattern.firstMatch(text);
    
    if (weeksMatch != null) {
      final weeks = int.parse(weeksMatch.group(1)!);
      final targetDate = now.add(Duration(days: weeks * 7));
      return DateTime(targetDate.year, targetDate.month, targetDate.day);
    }
    
    // Check for "next week"
    if (text.contains('next week')) {
      final targetDate = now.add(const Duration(days: 7));
      return DateTime(targetDate.year, targetDate.month, targetDate.day);
    }
    
    // Check for "next month"
    if (text.contains('next month')) {
      final targetDate = DateTime(now.year, now.month + 1, now.day);
      return DateTime(targetDate.year, targetDate.month, targetDate.day);
    }
    
    return null;
  }
  
  // Extract repeat options from text
  static String _extractRepeatOption(String text) {
    // Check for hourly patterns
    if (text.contains('every hour') || text.contains('hourly') || 
        text.contains('repeat every hour') || text.contains('each hour')) {
      return 'Every Hour';
    }
    
    // Check for daily patterns
    if (text.contains('every day') || text.contains('daily') || 
        text.contains('repeat every day') || text.contains('each day') ||
        text.contains('repeat daily')) {
      return 'Every Day';
    }
    
    // Check for weekly patterns
    if (text.contains('every week') || text.contains('weekly') || 
        text.contains('repeat every week') || text.contains('each week')) {
      return 'Every Week';
    }
    
    // Check for monthly patterns
    if (text.contains('every month') || text.contains('monthly') || 
        text.contains('repeat every month') || text.contains('each month')) {
      return 'Every Month';
    }
    
    // Check for specific weekday patterns
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (final weekday in weekdays) {
      if (text.contains('every $weekday') || text.contains('each $weekday') || 
          text.contains('repeat every $weekday') || text.contains('repeat $weekday')) {
        return 'Every $weekday';
      }
    }
    
    // Check for "remind me again in X" patterns (snooze-like but for repeat)
    final remindAgainPattern = RegExp(r'remind\s+me\s+again\s+in\s+(\d+)\s*(minutes?|hours?|mins?|hrs?)', caseSensitive: false);
    final remindAgainMatch = remindAgainPattern.firstMatch(text);
    
    if (remindAgainMatch != null) {
      final number = int.parse(remindAgainMatch.group(1)!);
      final unit = remindAgainMatch.group(2)!.toLowerCase();
      
      if (unit.startsWith('minute') || unit.startsWith('min')) {
        return 'Every ${number} Min';
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        return 'Every ${number} Hour';
      }
    }
    
    // Check for custom intervals with written numbers
    final writtenNumbers = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20,
      'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60
    };
    
    // Check for written number patterns like "every ten minutes"
    for (final entry in writtenNumbers.entries) {
      final writtenPattern = RegExp(r'every\s+' + entry.key + r'\s+(minutes?|hours?|days?|weeks?|months?)', caseSensitive: false);
      final writtenMatch = writtenPattern.firstMatch(text);
      
      if (writtenMatch != null) {
        final number = entry.value;
        final unit = writtenMatch.group(1)!.toLowerCase();
        
        if (unit.startsWith('minute')) {
          return 'Every ${number} Min';
        } else if (unit.startsWith('hour')) {
          return 'Every ${number} Hour';
        } else if (unit.startsWith('day')) {
          return 'Every ${number} Day';
        } else if (unit.startsWith('week')) {
          return 'Every ${number} Week';
        } else if (unit.startsWith('month')) {
          return 'Every ${number} Month';
        }
      }
    }
    
    // Check for custom intervals with numeric patterns
    final customPattern = RegExp(r'every\s+(\d+)\s+(minutes?|hours?|days?|weeks?|months?)', caseSensitive: false);
    final customMatch = customPattern.firstMatch(text);
    
    if (customMatch != null) {
      final number = int.parse(customMatch.group(1)!);
      final unit = customMatch.group(2)!.toLowerCase();
      
      if (unit.startsWith('minute')) {
        return 'Every ${number} Min';
      } else if (unit.startsWith('hour')) {
        return 'Every ${number} Hour';
      } else if (unit.startsWith('day')) {
        return 'Every ${number} Day';
      } else if (unit.startsWith('week')) {
        return 'Every ${number} Week';
      } else if (unit.startsWith('month')) {
        return 'Every ${number} Month';
      }
    }
    
    // Check for "repeat daily at X" patterns
    final repeatDailyPattern = RegExp(r'repeat\s+daily\s+at\s+(\d{1,2}):?(\d{2})?\s*(am|pm)?', caseSensitive: false);
    final repeatDailyMatch = repeatDailyPattern.firstMatch(text);
    
    if (repeatDailyMatch != null) {
      return 'Every Day';
    }
    
    return 'No Repeat';
  }
  
  // Extract snooze options from text
  static String _extractSnoozeOption(String text) {
    // Check for "remind me again in X" patterns (snooze-like)
    final remindAgainPattern = RegExp(r'remind\s+me\s+again\s+in\s+(\d+)\s*(minutes?|hours?|mins?|hrs?)', caseSensitive: false);
    final remindAgainMatch = remindAgainPattern.firstMatch(text);
    
    if (remindAgainMatch != null) {
      final number = int.parse(remindAgainMatch.group(1)!);
      final unit = remindAgainMatch.group(2)!.toLowerCase();
      
      if (unit.startsWith('minute') || unit.startsWith('min')) {
        return '${number} Min';
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        return '${number} Hour';
      }
    }
    
    // Check for specific snooze durations with written numbers
    final writtenNumbers = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20,
      'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60
    };
    
    // Check for written number snooze patterns
    for (final entry in writtenNumbers.entries) {
      final snoozeWrittenPattern = RegExp(r'snooze\s+(?:for\s+)?' + entry.key + r'\s+(minutes?|hours?|mins?|hrs?)', caseSensitive: false);
      final snoozeWrittenMatch = snoozeWrittenPattern.firstMatch(text);
      
      if (snoozeWrittenMatch != null) {
        final number = entry.value;
        final unit = snoozeWrittenMatch.group(1)!.toLowerCase();
        
        if (unit.startsWith('minute') || unit.startsWith('min')) {
          return '${number} Min';
        } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
          return '${number} Hour';
        }
      }
    }
    
    // Check for specific snooze durations with numeric patterns
    final snoozePattern = RegExp(r'snooze\s+(?:for\s+)?(\d+)\s*(minutes?|hours?|mins?|hrs?)', caseSensitive: false);
    final snoozeMatch = snoozePattern.firstMatch(text);
    
    if (snoozeMatch != null) {
      final number = int.parse(snoozeMatch.group(1)!);
      final unit = snoozeMatch.group(2)!.toLowerCase();
      
      if (unit.startsWith('minute') || unit.startsWith('min')) {
        return '${number} Min';
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        return '${number} Hour';
      }
    }
    
    // Check for common snooze phrases with written numbers
    final commonSnoozePhrases = {
      'snooze for five minutes': '5 Min',
      'five minute snooze': '5 Min',
      'snooze for ten minutes': '10 Min',
      'ten minute snooze': '10 Min',
      'snooze for fifteen minutes': '15 Min',
      'fifteen minute snooze': '15 Min',
      'snooze for thirty minutes': '30 Min',
      'thirty minute snooze': '30 Min',
      'snooze for one hour': '1 Hour',
      'one hour snooze': '1 Hour',
    };
    
    for (final entry in commonSnoozePhrases.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Check for common snooze phrases with numeric patterns
    if (text.contains('snooze for 5 minutes') || text.contains('5 minute snooze')) {
      return '5 Min';
    }
    
    if (text.contains('snooze for 10 minutes') || text.contains('10 minute snooze')) {
      return '10 Min';
    }
    
    if (text.contains('snooze for 15 minutes') || text.contains('15 minute snooze')) {
      return '15 Min';
    }
    
    if (text.contains('snooze for 30 minutes') || text.contains('30 minute snooze')) {
      return '30 Min';
    }
    
    if (text.contains('snooze for 1 hour') || text.contains('1 hour snooze')) {
      return '1 Hour';
    }
    
    // Check for "in X minutes" patterns (snooze-like)
    final inMinutesPattern = RegExp(r'in\s+(\d+)\s*(minutes?|mins?)', caseSensitive: false);
    final inMinutesMatch = inMinutesPattern.firstMatch(text);
    
    if (inMinutesMatch != null) {
      final number = int.parse(inMinutesMatch.group(1)!);
      return '${number} Min';
    }
    
    // Check for "in X hours" patterns (snooze-like)
    final inHoursPattern = RegExp(r'in\s+(\d+)\s*(hours?|hrs?)', caseSensitive: false);
    final inHoursMatch = inHoursPattern.firstMatch(text);
    
    if (inHoursMatch != null) {
      final number = int.parse(inHoursMatch.group(1)!);
      return '${number} Hour';
    }
    
    // Default snooze
    return '5 Min';
  }
  
  // Extract title by removing date/time/repeat/snooze phrases
  // Improved to preserve more of the original meaning
  static String _extractTitle(String originalText, String lowerText) {
    String title = originalText;
    
    // Remove common reminder prefixes (be more careful)
    final prefixes = [
      'remind me to ',
      'remind me of ',
      'remind me about ',
      'reminder to ',
      'reminder for ',
      'reminder about ',
      'remind me ',
      'reminder ',
      'set a reminder to ',
      'set a reminder for ',
      'set reminder to ',
      'set reminder for ',
    ];
    
    for (final prefix in prefixes) {
      if (lowerText.startsWith(prefix)) {
        title = title.substring(prefix.length);
        break;
      }
    }
    
    // Remove time phrases - be more precise to avoid removing words that contain time-like patterns
    // Match complete time phrases with word boundaries
    title = title.replaceAll(RegExp(r'\s+at\s+\d{1,2}:\d{2}\s*(am|pm)\b', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s+at\s+\d{1,2}\s*(am|pm)\b', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s+\d{1,2}:\d{2}\s*(am|pm)\b', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s+\d{1,2}\s*(am|pm)\b', caseSensitive: false), '');
    // Remove "at" preposition that might be left after removing time
    title = title.replaceAll(RegExp(r'\s+at\s+', caseSensitive: false), ' ');
    
    // Check if title contains holiday names - if so, be more careful about what we remove
    final holidayNames = ['christmas', 'new year', 'valentine', 'easter', 'halloween', 
                          'thanksgiving', 'labor day', 'memorial day', 'mother\'s day', 'father\'s day'];
    final hasHoliday = holidayNames.any((holiday) => lowerText.contains(holiday));
    
    // Remove date phrases (but be careful with holidays)
    final dateKeywords = [
      'on today', 'today',
      'on tomorrow', 'tomorrow',
      'day after tomorrow',
      'on monday', 'on tuesday', 'on wednesday', 'on thursday',
      'on friday', 'on saturday', 'on sunday',
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
      'next week', 'next month',
      'in \\d+ days?', 'in \\d+ weeks?',
    ];
    
    // Only remove date keywords if they're not part of holiday names
    for (final keyword in dateKeywords) {
      // Don't remove if it's part of a holiday phrase
      if (!hasHoliday || !lowerText.contains(keyword + ' ' + holidayNames.join('|'))) {
        title = title.replaceAll(RegExp('\\s+' + keyword, caseSensitive: false), '');
        title = title.replaceAll(RegExp(keyword + '\\s+', caseSensitive: false), '');
      }
    }
    
    // Remove month names with dates (but keep holiday names)
    final months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
      'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'sept', 'oct', 'nov', 'dec',
    ];
    
    // Don't remove month if it's part of a holiday name
    final holidayKeywords = ['christmas', 'new year', 'valentine', 'easter', 'halloween', 
                             'thanksgiving', 'labor day', 'memorial day', 'mother', 'father'];
    final containsHoliday = holidayKeywords.any((keyword) => title.toLowerCase().contains(keyword));
    
    if (!containsHoliday) {
      for (final month in months) {
        // Remove "25th october" pattern
        title = title.replaceAll(RegExp(r'\s+\d{1,2}(?:st|nd|rd|th)?\s+' + month, caseSensitive: false), '');
        // Remove "october 25" pattern
        title = title.replaceAll(RegExp(month + r'\s+\d{1,2}(?:st|nd|rd|th)?', caseSensitive: false), '');
        // Remove standalone month (but be careful with holiday context)
        title = title.replaceAll(RegExp(r'\s+' + month + r'\s+', caseSensitive: false), ' ');
      }
    }
    
    // Remove repeat phrases
    final repeatPhrases = [
      'every hour', 'hourly', 'repeat every hour', 'each hour',
      'every day', 'daily', 'repeat every day', 'each day', 'repeat daily',
      'every week', 'weekly', 'repeat every week', 'each week',
      'every month', 'monthly', 'repeat every month', 'each month',
      'every monday', 'every tuesday', 'every wednesday', 'every thursday',
      'every friday', 'every saturday', 'every sunday',
      'repeat monday', 'repeat tuesday', 'repeat wednesday', 'repeat thursday',
      'repeat friday', 'repeat saturday', 'repeat sunday',
      'repeat the reminder', 'repeat reminder',
      'remind me again in', 'remind me again',
    ];
    
    for (final phrase in repeatPhrases) {
      title = title.replaceAll(RegExp('\\s+' + phrase, caseSensitive: false), '');
      title = title.replaceAll(RegExp(phrase + '\\s+', caseSensitive: false), '');
    }
    
    // Remove snooze phrases
    final snoozePhrases = [
      'snooze for \\d+ minutes?', 'snooze for \\d+ hours?',
      '\\d+ minute snooze', '\\d+ hour snooze',
      'snooze \\d+ min', 'snooze \\d+ hour',
      'snooze for five minutes', 'snooze for ten minutes', 'snooze for fifteen minutes',
      'snooze for thirty minutes', 'snooze for one hour',
      'five minute snooze', 'ten minute snooze', 'fifteen minute snooze',
      'thirty minute snooze', 'one hour snooze',
      'in \\d+ minutes?', 'in \\d+ hours?',
      'remind me again in \\d+ minutes?', 'remind me again in \\d+ hours?',
    ];
    
    for (final phrase in snoozePhrases) {
      title = title.replaceAll(RegExp('\\s+' + phrase, caseSensitive: false), '');
      title = title.replaceAll(RegExp(phrase + '\\s+', caseSensitive: false), '');
    }
    
    // Remove "on" preposition if it's at the start
    title = title.replaceAll(RegExp(r'^\s*on\s+', caseSensitive: false), '');
    
    // Clean up extra spaces
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // If title is empty or too short after all removals, use original text with minimal cleaning
    if (title.isEmpty || title.length < 3) {
      // Fallback: just remove the most basic prefixes
      title = originalText;
      for (final prefix in ['remind me to ', 'remind me of ', 'remind me about ', 'remind me ']) {
        if (lowerText.startsWith(prefix)) {
          title = title.substring(prefix.length).trim();
          break;
        }
      }
      // If still empty, use original
      if (title.isEmpty) {
        title = originalText;
      }
    }
    
    return title;
  }
}

