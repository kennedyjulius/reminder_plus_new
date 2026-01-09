import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../services/calendar_sync_service.dart';
import '../services/background_task_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsModel? _settings;
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading settings: $e');
    }
  }

  Future<void> _updateSettings(SettingsModel newSettings) async {
    try {
      await SettingsService.saveSettings(newSettings);
      setState(() {
        _settings = newSettings;
      });
    } catch (e) {
      _showErrorSnackBar('Error updating settings: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.inputBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.confirmButton.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.confirmButton,
                    size: 20,
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
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? const Icon(
                  Icons.keyboard_arrow_right,
                  color: AppColors.primaryText,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.settingsHeading,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    return _buildSettingsItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.saveButton,
        activeTrackColor: AppColors.saveButton.withOpacity(0.3),
        inactiveThumbColor: AppColors.toggleThumb,
        inactiveTrackColor: AppColors.toggleTrack,
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    ValueChanged<String>? onChanged,
    required IconData icon,
  }) {
    return _buildSettingsItem(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged != null ? (String? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        } : null,
        underline: Container(),
        style: GoogleFonts.roboto(color: AppColors.primaryText),
        dropdownColor: AppColors.cardBackground,
        items: options.map<DropdownMenuItem<String>>((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              style: GoogleFonts.roboto(color: AppColors.primaryText),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _showNotificationSoundPicker() async {
    final sounds = [
      'soft_chime.mp3',
      'gentle_bell.mp3',
      'classic_alarm.mp3',
      'digital_beep.mp3',
      'nature_sound.mp3',
      'default.mp3',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Notification Sound',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            ...sounds.map((sound) => ListTile(
              title: Text(
                sound.replaceAll('.mp3', ''),
                style: GoogleFonts.roboto(color: AppColors.primaryText),
              ),
              trailing: _settings!.reminderSettings.notificationSound == sound
                  ? const Icon(Icons.check, color: AppColors.confirmButton)
                  : null,
              onTap: () async {
                await _audioPlayer.play(AssetSource('sounds/$sound'));
                _updateReminderSettings(
                  _settings!.reminderSettings.copyWith(notificationSound: sound),
                );
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePicker() async {
    final time = TimeOfDay.fromDateTime(
      DateTime.parse('2023-01-01 ${_settings!.reminderSettings.defaultTime}:00'),
    );
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: time,
    );
    
    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      _updateReminderSettings(
        _settings!.reminderSettings.copyWith(defaultTime: timeString),
      );
    }
  }

  void _updateReminderSettings(ReminderSettings newSettings) {
    _updateSettings(_settings!.copyWith(reminderSettings: newSettings));
  }

  void _updateEmailSettings(EmailSettings newSettings) {
    _updateSettings(_settings!.copyWith(emailSettings: newSettings));
  }

  void _updateCalendarSettings(CalendarSettings newSettings) {
    _updateSettings(_settings!.copyWith(calendarSettings: newSettings));
  }

  Future<void> _updateSyncSettings(SyncSettings newSettings) async {
    await _updateSettings(_settings!.copyWith(syncSettings: newSettings));
  }

  List<String> _getCommonTimezones() {
    return [
      'UTC',
      'America/New_York', // EST/EDT
      'America/Chicago', // CST/CDT
      'America/Denver', // MST/MDT
      'America/Los_Angeles', // PST/PDT
      'America/Phoenix', // MST (no DST)
      'America/Toronto', // EST/EDT
      'America/Vancouver', // PST/PDT
      'Europe/London', // GMT/BST
      'Europe/Paris', // CET/CEST
      'Europe/Berlin', // CET/CEST
      'Europe/Rome', // CET/CEST
      'Europe/Madrid', // CET/CEST
      'Asia/Tokyo', // JST
      'Asia/Shanghai', // CST
      'Asia/Hong_Kong', // HKT
      'Asia/Singapore', // SGT
      'Asia/Dubai', // GST
      'Asia/Kolkata', // IST
      'Asia/Karachi', // PKT
      'Australia/Sydney', // AEDT/AEST
      'Australia/Melbourne', // AEDT/AEST
      'Pacific/Auckland', // NZDT/NZST
      'Africa/Lagos', // WAT
      'Africa/Johannesburg', // SAST
      'America/Sao_Paulo', // BRT/BRST
      'America/Mexico_City', // CST/CDT
      'America/Buenos_Aires', // ART
    ];
  }

  Future<void> _manageAccounts() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Connected Accounts',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 20),
            
            // Gmail Account
            _buildAccountItem(
              title: 'Gmail',
              subtitle: _settings!.emailSettings.gmailConnected ? 'Connected' : 'Not connected',
              icon: Icons.mail,
              isConnected: _settings!.emailSettings.gmailConnected,
              onConnect: () {
                _updateEmailSettings(
                  _settings!.emailSettings.copyWith(gmailConnected: true),
                );
                _showSuccessSnackBar('Gmail connected successfully');
                Navigator.pop(context);
              },
              onDisconnect: () {
                _updateEmailSettings(
                  _settings!.emailSettings.copyWith(gmailConnected: false),
                );
                _showSuccessSnackBar('Gmail disconnected');
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 12),
            
            // Outlook Account
            _buildAccountItem(
              title: 'Outlook',
              subtitle: _settings!.emailSettings.outlookConnected ? 'Connected' : 'Not connected',
              icon: Icons.email,
              isConnected: _settings!.emailSettings.outlookConnected,
              onConnect: () {
                _updateEmailSettings(
                  _settings!.emailSettings.copyWith(outlookConnected: true),
                );
                _showSuccessSnackBar('Outlook connected successfully');
                Navigator.pop(context);
              },
              onDisconnect: () {
                _updateEmailSettings(
                  _settings!.emailSettings.copyWith(outlookConnected: false),
                );
                _showSuccessSnackBar('Outlook disconnected');
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 12),
            
            // Google Calendar Account
            _buildAccountItem(
              title: 'Google Calendar',
              subtitle: _settings!.calendarSettings.googleCalendarConnected ? 'Connected' : 'Not connected',
              icon: Icons.calendar_today,
              isConnected: _settings!.calendarSettings.googleCalendarConnected,
              onConnect: () {
                _updateCalendarSettings(
                  _settings!.calendarSettings.copyWith(googleCalendarConnected: true),
                );
                _showSuccessSnackBar('Google Calendar connected successfully');
                Navigator.pop(context);
              },
              onDisconnect: () {
                _updateCalendarSettings(
                  _settings!.calendarSettings.copyWith(googleCalendarConnected: false),
                );
                _showSuccessSnackBar('Google Calendar disconnected');
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 12),
            
            // Calendly Account
            _buildAccountItem(
              title: 'Calendly',
              subtitle: _settings!.calendarSettings.calendlyConnected ? 'Connected' : 'Not connected',
              icon: Icons.event,
              isConnected: _settings!.calendarSettings.calendlyConnected,
              onConnect: () {
                _updateCalendarSettings(
                  _settings!.calendarSettings.copyWith(calendlyConnected: true),
                );
                _showSuccessSnackBar('Calendly connected successfully');
                Navigator.pop(context);
              },
              onDisconnect: () {
                _updateCalendarSettings(
                  _settings!.calendarSettings.copyWith(calendlyConnected: false),
                );
                _showSuccessSnackBar('Calendly disconnected');
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : AppColors.inputBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.withOpacity(0.1) : AppColors.confirmButton.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isConnected ? Colors.green : AppColors.confirmButton,
              size: 20,
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
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: isConnected ? Colors.green : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isConnected ? onDisconnect : onConnect,
            icon: Icon(
              isConnected ? Icons.close : Icons.add,
              color: isConnected ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _syncCalendars() async {
    try {
      await CalendarSyncService().syncAllCalendars();
      _showSuccessSnackBar('Calendar sync completed');
    } catch (e) {
      _showErrorSnackBar('Calendar sync failed: $e');
    }
  }

  Future<void> _clearAllReminders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear All Reminders',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete all reminders? This action cannot be undone.',
          style: GoogleFonts.roboto(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.roboto()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete All', style: GoogleFonts.roboto(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement clear all reminders
      _showSuccessSnackBar('All reminders cleared');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: GoogleFonts.roboto(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.roboto()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete Account', style: GoogleFonts.roboto(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement delete account
      _showSuccessSnackBar('Account deletion initiated');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.roboto(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.roboto()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: GoogleFonts.roboto(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        _showErrorSnackBar('Logout failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primaryText,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reminder Settings Section
                    _buildSectionTitle('🕐 Reminder Settings'),
                    
                    _buildSettingsItem(
                      title: 'Default Reminder Time',
                      subtitle: _settings!.reminderSettings.defaultTime,
                      icon: Icons.access_time,
                      onTap: () => _showTimePicker(),
                    ),
                    
                    _buildDropdownTile(
                      title: 'Snooze Duration',
                      subtitle: '${_settings!.reminderSettings.snoozeDuration} minutes',
                      value: _settings!.reminderSettings.snoozeDuration.toString(),
                      options: ['5', '10', '15', '30', '60'],
                      onChanged: (value) {
                        _updateReminderSettings(
                          _settings!.reminderSettings.copyWith(
                            snoozeDuration: int.parse(value),
                          ),
                        );
                      },
                      icon: Icons.snooze,
                    ),
                    
                    _buildSettingsItem(
                      title: 'Notification Sound',
                      subtitle: _settings!.reminderSettings.notificationSound.replaceAll('.mp3', ''),
                      icon: Icons.notifications,
                      onTap: _showNotificationSoundPicker,
                    ),
                    
                    _buildSwitchTile(
                      title: 'Vibration',
                      subtitle: 'Vibrate on notification',
                      value: _settings!.reminderSettings.vibration,
                      onChanged: (value) {
                        _updateReminderSettings(
                          _settings!.reminderSettings.copyWith(vibration: value),
                        );
                      },
                      icon: Icons.vibration,
                    ),
                    
                    _buildSwitchTile(
                      title: 'Smart Notifications',
                      subtitle: 'Intelligent notification timing',
                      value: _settings!.reminderSettings.smartNotifications,
                      onChanged: (value) {
                        _updateReminderSettings(
                          _settings!.reminderSettings.copyWith(smartNotifications: value),
                        );
                      },
                      icon: Icons.psychology,
                    ),

                    // Email Integration Section
                    _buildSectionTitle('📧 Email Integration'),
                    
                    _buildSwitchTile(
                      title: 'Email Parsing',
                      subtitle: 'Auto-create reminders from emails',
                      value: _settings!.emailSettings.emailParsing,
                      onChanged: (value) {
                        _updateEmailSettings(
                          _settings!.emailSettings.copyWith(emailParsing: value),
                        );
                      },
                      icon: Icons.auto_awesome,
                    ),
                    
                    _buildDropdownTile(
                      title: 'Sync Interval',
                      subtitle: _settings!.emailSettings.syncInterval,
                      value: _settings!.emailSettings.syncInterval,
                      options: SettingsService.getAvailableSyncFrequencies(),
                      onChanged: (value) {
                        _updateEmailSettings(
                          _settings!.emailSettings.copyWith(syncInterval: value),
                        );
                      },
                      icon: Icons.sync,
                    ),

                    // General Settings Section
                    _buildSectionTitle('⚙️ General Settings'),
                    
                    _buildDropdownTile(
                      title: 'Timezone',
                      subtitle: _settings!.syncSettings.timezone,
                      value: _settings!.syncSettings.timezone,
                      options: _getCommonTimezones(),
                      onChanged: (value) async {
                        final oldTimezone = _settings!.syncSettings.timezone;
                        await _updateSyncSettings(
                          _settings!.syncSettings.copyWith(timezone: value),
                        );
                        _showSuccessSnackBar('Timezone updated to $value');
                        
                        // Re-schedule all reminders with new timezone
                        try {
                          await BackgroundTaskService.rescheduleAllReminders();
                          _showSuccessSnackBar('All reminders re-scheduled for new timezone');
                        } catch (e) {
                          print('⚠️ Error re-scheduling reminders: $e');
                          _showErrorSnackBar('Timezone updated, but reminders may need to be re-scheduled');
                        }
                      },
                      icon: Icons.access_time,
                    ),

                    // Calendar Settings Section
                    _buildSectionTitle('📅 Calendar Settings'),
                    
                    _buildSwitchTile(
                      title: 'Auto Sync',
                      subtitle: 'Automatically sync calendar events',
                      value: _settings!.calendarSettings.autoSync,
                      onChanged: (value) {
                        _updateCalendarSettings(
                          _settings!.calendarSettings.copyWith(autoSync: value),
                        );
                      },
                      icon: Icons.sync,
                    ),
                    
                    _buildDropdownTile(
                      title: 'Sync Frequency',
                      subtitle: _settings!.calendarSettings.syncFrequency,
                      value: _settings!.calendarSettings.syncFrequency,
                      options: SettingsService.getAvailableSyncFrequencies(),
                      onChanged: (value) {
                        _updateCalendarSettings(
                          _settings!.calendarSettings.copyWith(syncFrequency: value),
                        );
                      },
                      icon: Icons.timer,
                    ),
                    
                    _buildSwitchTile(
                      title: 'Create Reminders for Events',
                      subtitle: 'Convert calendar events to reminders',
                      value: _settings!.calendarSettings.createRemindersForEvents,
                      onChanged: (value) {
                        _updateCalendarSettings(
                          _settings!.calendarSettings.copyWith(createRemindersForEvents: value),
                        );
                      },
                      icon: Icons.add_alert,
                    ),
                    
                    _buildSwitchTile(
                      title: 'Include All-Day Events',
                      subtitle: 'Include all-day calendar events',
                      value: _settings!.calendarSettings.includeAllDayEvents,
                      onChanged: (value) {
                        _updateCalendarSettings(
                          _settings!.calendarSettings.copyWith(includeAllDayEvents: value),
                        );
                      },
                      icon: Icons.event_available,
                    ),
                    
                    _buildSettingsItem(
                      title: 'Sync Now',
                      subtitle: 'Manually sync calendar events',
                      icon: Icons.sync_alt,
                      onTap: _syncCalendars,
                    ),

                    // Account & Privacy Section
                    _buildSectionTitle('🔐 Account & Privacy'),
                    
                    _buildSettingsItem(
                      title: 'Manage Connected Accounts',
                      subtitle: 'Gmail, Outlook, Google Calendar, etc.',
                      icon: Icons.account_circle,
                      onTap: _manageAccounts,
                    ),
                    
                    _buildSettingsItem(
                      title: 'Clear All Reminders',
                      subtitle: 'Delete all reminders',
                      icon: Icons.delete_sweep,
                      onTap: _clearAllReminders,
                    ),
                    
                    _buildSettingsItem(
                      title: 'Delete Account',
                      subtitle: 'Permanently delete account',
                      icon: Icons.delete_forever,
                      onTap: _deleteAccount,
                    ),
                    
                    _buildSettingsItem(
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      icon: Icons.logout,
                      onTap: _logout,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
