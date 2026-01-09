import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/firebase_service.dart';
import '../services/reminder_service.dart';
import '../services/notification_service.dart';
import '../services/background_task_service.dart';
import '../services/stock_service.dart';
import '../services/holiday_service.dart';
import '../models/reminder_model.dart';
import '../widgets/action_button.dart';
import '../widgets/reminder_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  bool _isLoading = true;
  int _refreshKey = 0; // Key to force StreamBuilder refresh
  bool _bannerLoading = true;
  List<StockQuote> _majorQuotes = [];
  List<Holiday> _upcomingHolidays = [];
  final PageController _stockPageController = PageController(viewportFraction: 0.72);
  int _currentStockPage = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadBannerData();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userDoc = await FirebaseService.getUserProfile();
      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['displayName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
          _isLoading = false;
        });
      }
      
      // Start background tasks for seamless notifications
      await BackgroundTaskService.startBackgroundTasks();
      
      // Check notification permissions
      final notificationsEnabled = await NotificationService.areNotificationsEnabled();
      print('Notifications enabled: $notificationsEnabled');
      
      if (!notificationsEnabled) {
        print('Requesting notification permissions...');
        final granted = await NotificationService.requestPermissions();
        print('Permission granted: $granted');
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
        _isLoading = false;
      });
      
      // Still try to start background tasks even if profile loading fails
      await BackgroundTaskService.startBackgroundTasks();
    }
  }

  Future<void> _loadBannerData() async {
    try {
      print('Loading banner data...');
      setState(() {
        _bannerLoading = true;
      });
      
      // Load stocks and holidays in parallel
      final results = await Future.wait([
        StockService.fetchTopMajors().catchError((e) {
          print('Error fetching stocks: $e');
          return <StockQuote>[];
        }),
        HolidayService.getUpcomingHolidays(
          country: 'US',
          daysAhead: 60,
          limit: 3,
        ).catchError((e) {
          print('Error fetching holidays: $e');
          return <Holiday>[];
        }),
      ]);
      
      final quotes = results[0] as List<StockQuote>;
      final holidays = results[1] as List<Holiday>;
      
      print('Loaded ${quotes.length} stock quotes and ${holidays.length} holidays');
      
      if (mounted) {
        setState(() {
          _majorQuotes = quotes;
          _upcomingHolidays = holidays;
          _bannerLoading = false;
        });
        print('Banner data loaded successfully. Quotes: ${quotes.length}, Holidays: ${holidays.length}');
      }
    } catch (e, stackTrace) {
      print('Error loading banner data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _majorQuotes = [];
          _upcomingHolidays = [];
          _bannerLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stockPageController.dispose();
    super.dispose();
  }

  Future<void> _syncEvents() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Syncing reminders...',
                style: GoogleFonts.roboto(
                  color: AppColors.primaryText,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Force refresh the reminders stream by updating the key
      await Future.delayed(const Duration(milliseconds: 500)); // Brief delay for UX
      
      if (mounted) {
        // Update refresh key to force StreamBuilder to recreate
        setState(() {
          _refreshKey++;
        });
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminders refreshed successfully!',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync failed: ${e.toString()}',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good morning';
    
    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17) {
      greeting = 'Good evening';
    }

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Title and Sync Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voice Reminder+',
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _syncEvents,
                            icon: const Icon(
                              Icons.sync,
                              color: AppColors.primaryText,
                              size: 24,
                            ),
                            tooltip: 'Sync Events',
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            },
                            icon: const Icon(
                              Icons.settings,
                              color: AppColors.primaryText,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Greeting
                  Text(
                    _isLoading ? '$greeting...' : '$greeting, $_userName',
                    style: GoogleFonts.roboto(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Date
                  Text(
                    'Today, ${months[now.month - 1]} ${now.day}, ${now.year}',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      title: 'Email Events',
                      icon: Icons.email_outlined,
                      gradient: AppColors.emailEventsGradient,
                      onTap: () {
                        Navigator.pushNamed(context, '/email-parsing');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      title: 'Screen Scan',
                      icon: Icons.qr_code_scanner_outlined,
                      gradient: null,
                      color: AppColors.screenScanSolid,
                      onTap: () {
                        Navigator.pushNamed(context, '/screen-scan');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      title: 'Voice Command',
                      icon: Icons.mic,
                      gradient: AppColors.voiceCommandGradient,
                      onTap: () {
                        Navigator.pushNamed(context, '/voice-command');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildHighlightsBanner(),
            ),
            
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      title: 'Stock Alerts',
                      icon: Icons.trending_up,
                      gradient: AppColors.voiceCommandGradient,
                      onTap: () {
                        Navigator.pushNamed(context, '/api-tools');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      title: 'Holiday Sync',
                      icon: Icons.event_available_outlined,
                      gradient: AppColors.emailEventsGradient,
                      onTap: () {
                        Navigator.pushNamed(context, '/api-tools');
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Upcoming Reminders Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upcoming Reminders',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Reminders List from Firestore
                  SizedBox(
                    height: 400, // Fixed height for scrollable list
                    child: StreamBuilder<List<ReminderModel>>(
                        key: ValueKey(_refreshKey),
                        stream: ReminderService.getUserReminders(),
                        builder: (context, snapshot) {
                          // Handle waiting state with timeout consideration
                          if (snapshot.connectionState == ConnectionState.waiting && 
                              !snapshot.hasData) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading reminders...',
                                    style: GoogleFonts.roboto(
                                      color: AppColors.secondaryText,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // If we have data but it's empty, show empty state immediately
                          if (snapshot.hasData && snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardBackground,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.inputBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.event_note_outlined,
                                            color: AppColors.secondaryText,
                                            size: 64,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No reminders added',
                                            style: GoogleFonts.roboto(
                                              color: AppColors.primaryText,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Create your first reminder to get started',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.roboto(
                                              color: AppColors.secondaryText,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pushNamed(context, '/add-reminder');
                                            },
                                            icon: const Icon(Icons.add, color: Colors.white),
                                            label: Text(
                                              'Add Reminder',
                                              style: GoogleFonts.roboto(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.confirmButton,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading reminders',
                                      style: GoogleFonts.roboto(
                                        color: AppColors.primaryText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please check your connection and try again',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.roboto(
                                        color: AppColors.secondaryText,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {}); // Trigger rebuild to retry
                                      },
                                      icon: const Icon(Icons.refresh, color: Colors.white),
                                      label: Text(
                                        'Retry',
                                        style: GoogleFonts.roboto(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }


                          final reminders = snapshot.data!;

                          return ListView.builder(
                            itemCount: reminders.length,
                            itemBuilder: (context, index) {
                              final reminder = reminders[index];
                              
                              // Format date
                              final now = DateTime.now();
                              final reminderDate = reminder.dateTime;
                              String dateString;
                              
                              // Check if it's today, tomorrow, or show full date
                              if (reminderDate.year == now.year && 
                                  reminderDate.month == now.month && 
                                  reminderDate.day == now.day) {
                                dateString = 'Today';
                              } else if (reminderDate.year == now.year && 
                                        reminderDate.month == now.month && 
                                        reminderDate.day == now.day + 1) {
                                dateString = 'Tomorrow';
                              } else {
                                // Format as "Jan 15, 2026" or "15/01/2026"
                                final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                dateString = '${months[reminderDate.month - 1]} ${reminderDate.day}, ${reminderDate.year}';
                              }
                              
                              // Format time
                              final hour = reminder.dateTime.hour;
                              final minute = reminder.dateTime.minute;
                              final period = hour >= 12 ? 'PM' : 'AM';
                              final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                              final timeString = '$displayHour:${minute.toString().padLeft(2, '0')} $period';

                              return Padding(
                                padding: EdgeInsets.only(bottom: index < reminders.length - 1 ? 12 : 0),
                                child: ReminderCard(
                                  title: reminder.title,
                                  time: timeString,
                                  date: dateString,
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
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 30), // Bottom padding
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHighlightsBanner() {
    final hasData = _majorQuotes.isNotEmpty || _upcomingHolidays.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.voiceCommandStart, AppColors.voiceCommandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_graph, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Today\'s Highlights',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    onPressed: () {
                      setState(() {
                        _bannerLoading = true;
                      });
                      _loadBannerData();
                    },
                    tooltip: 'Refresh',
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/api-tools'),
                    child: Text(
                      'Open tools',
                      style: GoogleFonts.roboto(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bannerLoading)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading highlights...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            )
          else if (!hasData)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
                  'No highlights available',
                  style: GoogleFonts.roboto(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap refresh or "Open tools" to load stock data and holidays.',
                  style: GoogleFonts.roboto(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                if (_majorQuotes.isEmpty && _upcomingHolidays.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Note: Make sure you have a valid Finnhub API key configured.',
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            )
          else ...[
            if (_majorQuotes.isNotEmpty) ...[
              Text(
                'Top Movers',
                style: GoogleFonts.roboto(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: PageView.builder(
                  controller: _stockPageController,
                  itemCount: _majorQuotes.length,
                  onPageChanged: (i) => setState(() => _currentStockPage = i),
                  padEnds: false,
                  itemBuilder: (context, index) {
                    final quote = _majorQuotes[index];
                    final change = quote.current - quote.previousClose;
                    final pct = quote.previousClose == 0
                        ? 0
                        : (change / quote.previousClose) * 100;
                    final positive = change >= 0;
                    return AnimatedBuilder(
                      animation: _stockPageController,
                      builder: (context, child) {
                        double scale = 1.0;
                        if (_stockPageController.position.haveDimensions) {
                          final page = _stockPageController.page ?? 0.0;
                          scale = (1 - (page - index).abs() * 0.1).clamp(0.9, 1.0);
                        }
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index == _majorQuotes.length - 1 ? 0 : 12,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      quote.symbol,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      positive ? Icons.trending_up : Icons.trending_down,
                                      color: positive ? Colors.greenAccent : Colors.redAccent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  quote.current.toStringAsFixed(2),
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${positive ? '+' : ''}${pct.toStringAsFixed(2)}%',
                                  style: GoogleFonts.roboto(
                                    color: positive ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_majorQuotes.length, (i) {
                  final active = i == _currentStockPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: active ? 18 : 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(active ? 0.9 : 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ],
            if (_upcomingHolidays.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Upcoming Holidays',
                style: GoogleFonts.roboto(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: _upcomingHolidays.map((h) {
                  final dateStr = '${h.date.day}/${h.date.month}/${h.date.year}';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            h.name,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.roboto(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
