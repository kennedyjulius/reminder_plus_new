import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class ReminderCard extends StatelessWidget {
  final String title;
  final String time;
  final String? date; // Optional date display
  final bool isCompleted;
  final VoidCallback? onTap;

  const ReminderCard({
    super.key,
    required this.title,
    required this.time,
    this.date,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        Navigator.pushNamed(context, '/reminder-details');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.reminderCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.inputBorder.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : AppColors.warningBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.warning,
                color: isCompleted ? Colors.white : AppColors.warningIcon,
                size: 20,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Title and Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppColors.secondaryText : AppColors.primaryText,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (date != null)
                    Text(
                      date!,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Icons
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    // Handle repeat action
                  },
                  icon: const Icon(
                    Icons.repeat,
                    color: AppColors.primaryText,
                    size: 20,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Handle add action
                  },
                  icon: const Icon(
                    Icons.add,
                    color: AppColors.primaryText,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
