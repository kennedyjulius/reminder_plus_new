import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              
              // App Logo and Title
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.iconGradient,
                ),
                child: const Icon(
                  Icons.mic,
                  size: 80,
                  color: AppColors.primaryText,
                ),
              ),
              
              const SizedBox(height: 40),
              
              Text(
                'Voice Reminder+',
                style: GoogleFonts.roboto(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Never miss an important moment',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Set reminders with your voice, get notified on time, and stay organized with our intelligent reminder system.',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // Features List
              Column(
                children: [
                  _buildFeatureItem(Icons.mic, 'Voice Commands', 'Set reminders using natural speech'),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.notifications, 'Smart Notifications', 'Get timely alerts and reminders'),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.cloud_sync, 'Cloud Sync', 'Access your reminders anywhere'),
                ],
              ),
              
              const Spacer(),
              
              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.confirmButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.iconGradient,
          ),
          child: Icon(
            icon,
            color: AppColors.primaryText,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
