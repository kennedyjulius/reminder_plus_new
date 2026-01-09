import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import '../services/tts_service.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Start animation immediately
      _animationController.forward();
      
      // Wait for minimum splash duration (2-3 seconds)
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      // Services are already initialized in main.dart
      // Just check if Firebase is available
      try {
        print('Checking Firebase status...');
        
        // Initialize TTS in background (non-blocking with timeout)
        if (Firebase.apps.isNotEmpty) {
          print('Firebase is initialized, initializing TTS in background...');
          // Initialize TTS with timeout to prevent freezing
          TTSService.initialize().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print('TTS initialization timed out, continuing anyway...');
            },
          ).catchError((error) {
            print('TTS initialization error: $error');
          });
        } else {
          print('Firebase not initialized, skipping TTS...');
        }
        
        // Don't wait for TTS, check authentication immediately
        print('Checking authentication status...');
        final user = FirebaseAuth.instance.currentUser;
        
        if (user != null) {
          // User is logged in, update last login and navigate to home
          try {
            await FirebaseService.updateLastLogin().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print('Update last login timed out');
              },
            );
          } catch (e) {
            print('Error updating last login: $e');
          }
          _navigateToHome();
        } else {
          // User is not logged in, navigate to onboarding
          _navigateToOnboarding();
        }
      } catch (firebaseError) {
        print('Firebase initialization failed: $firebaseError');
        // Navigate to onboarding even if Firebase fails
        _navigateToOnboarding();
      }
    } catch (e) {
      print('Error initializing app: $e');
      // On any error, navigate to onboarding
      if (mounted) {
        _navigateToOnboarding();
      }
    }
  }

  void _navigateToHome() {
    print('Navigating to home...');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigation(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToOnboarding() {
    print('Navigating to onboarding...');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon with Gradient
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.splashIconGradient,
                      ),
                      child: const Icon(
                        Icons.mic,
                        size: 60,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // App Title
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Voice Reminder',
                          style: GoogleFonts.roboto(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        TextSpan(
                          text: '+',
                          style: GoogleFonts.roboto(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.splashAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Loading Text
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Loading your reminders...',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                );
              },
            ),
            
            const Spacer(),
            
            // Version Number
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Version 1.0.0',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
