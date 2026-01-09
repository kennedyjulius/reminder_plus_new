import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';
import '../widgets/reminder_card.dart';

class MissedRemindersScreen extends StatelessWidget {
  const MissedRemindersScreen({super.key});

  String _formatDateLabel(DateTime reminderDate, DateTime now) {
    if (reminderDate.year == now.year &&
        reminderDate.month == now.month &&
        reminderDate.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (reminderDate.year == tomorrow.year &&
        reminderDate.month == tomorrow.month &&
        reminderDate.day == tomorrow.day) {
      return 'Tomorrow';
    }
    final months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[reminderDate.month - 1]} ${reminderDate.day}, ${reminderDate.year}';
  }

  String _formatTimeLabel(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Missed Reminders',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: StreamBuilder<List<ReminderModel>>(
        stream: ReminderService.getMissedReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reminders = snapshot.data ?? <ReminderModel>[];
          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: AppColors.secondaryText),
                  const SizedBox(height: 12),
                  Text(
                    'No missed reminders',
                    style: GoogleFonts.roboto(
                      color: AppColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Missed reminders show up here without alerts.',
                    style: GoogleFonts.roboto(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              final dateLabel = _formatDateLabel(reminder.dateTime, now);
              final timeLabel = _formatTimeLabel(reminder.dateTime);

              return Padding(
                padding: EdgeInsets.only(bottom: index < reminders.length - 1 ? 12 : 0),
                child: ReminderCard(
                  title: reminder.title,
                  date: '$dateLabel (missed)',
                  time: timeLabel,
                  isCompleted: reminder.isCompleted,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/reminder-details',
                      arguments: {'reminderId': reminder.id},
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}



