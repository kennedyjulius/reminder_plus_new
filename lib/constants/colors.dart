import 'package:flutter/material.dart';

class AppColors {
  // Primary Background Colors
  static const Color primaryBackground = Color(0xFF1A0033);
  static const Color secondaryBackground = Color(0xFF2C003E);
  static const Color cardBackground = Color(0xFF3A104E);
  static const Color reminderCardBackground = Color(0xFF2A1A3A);
  
  // Text Colors
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFCCCCCC);
  static const Color lightGrayText = Color(0xFFB0B0B0);
  
  // Action Button Colors
  static const Color emailEventsStart = Color(0xFF00CED1);
  static const Color emailEventsEnd = Color(0xFF8A2BE2);
  static const Color screenScanSolid = Color(0xFF8A2BE2);
  static const Color voiceCommandStart = Color(0xFF8A2BE2);
  static const Color voiceCommandEnd = Color(0xFFFF1493);
  
  // Interactive Elements
  static const Color confirmButton = Color(0xFF8A2BE2);
  static const Color addButton = Color(0xFF4169E1);
  static const Color inputBorder = Color(0xFF8A2BE2);
  static const Color inputBackground = Color(0xFF333333);
  
  // Warning and Alert Colors
  static const Color warningIcon = Color(0xFFFFD700);
  static const Color warningBackground = Color(0xFF2A1A3A);
  
  // Settings Section Colors
  static const Color settingsHeading = Color(0xFF8A2BE2);
  static const Color iconGradientStart = Color(0xFF00CED1);
  static const Color iconGradientEnd = Color(0xFF8A2BE2);
  
  // Toggle Switch Colors
  static const Color toggleTrack = Color(0xFF555555);
  static const Color toggleThumb = Color(0xFFFFFFFF);
  
  // Navigation Colors
  static const Color activeNavItem = Color(0xFF8A2BE2);
  static const Color inactiveNavItem = Color(0xFFFFFFFF);
  static const Color navBarBackground = Color(0xFF2A1A3A);
  static const Color navBarSeparator = Color(0xFFCCCCCC);
  
  // Splash Screen Colors
  static const Color splashBackground = Color(0xFF1A0026);
  static const Color splashIconGradientStart = Color(0xFF00CED1);
  static const Color splashIconGradientEnd = Color(0xFF8A2BE2);
  static const Color splashAccent = Color(0xFF8A2BE2);
  
  // Form and Input Colors
  static const Color deleteButton = Color(0xFF8A2BE2);
  static const Color saveButton = Color(0xFF8A2BE2);
  
  // Gradient Definitions
  static const LinearGradient emailEventsGradient = LinearGradient(
    colors: [emailEventsStart, emailEventsEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient voiceCommandGradient = LinearGradient(
    colors: [voiceCommandStart, voiceCommandEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient iconGradient = LinearGradient(
    colors: [iconGradientStart, iconGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient splashIconGradient = LinearGradient(
    colors: [splashIconGradientStart, splashIconGradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
