import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/colors.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_reminder_screen.dart';
import 'screens/reminder_details_screen.dart';
import 'screens/all_reminders_screen.dart';
import 'screens/email_parsing_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/voice_command_screen.dart';
import 'screens/screen_scan_screen.dart';
import 'screens/api_tools_screen.dart';
import 'screens/missed_reminders_screen.dart';
import 'services/settings_service.dart';
import 'services/background_task_service.dart';
import 'services/notification_service.dart';
import 'services/calendar_sync_service.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with error handling
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      // If Firebase is already initialized, continue
      print('Firebase initialization skipped: $e');
    }
    
  // Initialize services with error handling
  try {
    await SettingsService.initialize();
  } catch (e) {
    print('SettingsService initialization error: $e');
  }
  
  try {
    await NotificationService.initialize();
  } catch (e) {
    print('NotificationService initialization error: $e');
  }
  
  try {
    await BackgroundTaskService.initialize();
  } catch (e) {
    print('BackgroundTaskService initialization error: $e');
  }
  
  try {
    await CalendarSyncService().initialize();
  } catch (e) {
    print('CalendarSyncService initialization error: $e');
  }
    
    runApp(const ReminderPlusApp());
  } catch (e) {
    print('Critical error in main: $e');
    // Even if everything fails, try to run the app
    runApp(const ReminderPlusApp());
  }
}

class ReminderPlusApp extends StatelessWidget {
  const ReminderPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Reminder+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: GoogleFonts.roboto().fontFamily,
        scaffoldBackgroundColor: AppColors.primaryBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryBackground,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
      // Add error handling
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorDetails.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const SplashScreen()),
                      );
                    },
                    child: const Text('Restart App'),
                  ),
                ],
              ),
            ),
          );
        };
        return widget!;
      },
      routes: {
        '/home': (context) => const MainNavigation(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/add-reminder': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return AddReminderScreen(initialText: args?['text'] as String?);
        },
        '/reminder-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final reminderId = args?['reminderId'] as String? ?? '';
          return ReminderDetailsScreen(reminderId: reminderId);
        },
        '/email-parsing': (context) => const EmailParsingScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/voice-command': (context) => const VoiceCommandScreen(),
        '/screen-scan': (context) => const ScreenScanScreen(),
        '/api-tools': (context) => const ApiToolsScreen(),
        '/missed-reminders': (context) => const MissedRemindersScreen(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

        final List<Widget> _screens = [
          const HomeScreen(),
          const AllRemindersScreen(),
          const SizedBox(), // Placeholder for add button
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _ModernNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        onAdd: () => Navigator.pushNamed(context, '/add-reminder'),
      ),
    );
  }
}

class _ModernNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _ModernNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
          color: AppColors.navBarBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.navBarSeparator, width: 0.6),
        ),
            child: Row(
              children: [
              _NavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              const Spacer(),
              _AddFab(onAdd: onAdd),
              const Spacer(),
              _NavItem(
                label: 'All',
                icon: Icons.view_list_rounded,
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
            icon,
            color: isActive ? AppColors.activeNavItem : AppColors.inactiveNavItem,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
            label,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
              color: isActive ? AppColors.activeNavItem : AppColors.inactiveNavItem,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: isActive ? 14 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? AppColors.activeNavItem : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddFab({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
                  child: Container(
        width: 54,
        height: 36,
        decoration: BoxDecoration(
                      color: AppColors.addButton,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
          Icons.add_rounded,
                      color: AppColors.primaryText,
          size: 22,
        ),
      ),
    );
  }
}