import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';
import '../services/email_service.dart';

class ReminderDetailsScreen extends StatefulWidget {
  final String reminderId;
  
  const ReminderDetailsScreen({super.key, required this.reminderId});

  @override
  State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  ReminderModel? _reminder;
  bool _isLoading = true;
  bool _isEditing = false;
  
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedRepeat = 'No Repeat';
  String _selectedSnooze = '5 Min';

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  Future<void> _loadReminder() async {
    try {
      final reminder = await ReminderService.getReminderById(widget.reminderId);
      if (reminder != null) {
        setState(() {
          _reminder = reminder;
          _titleController.text = reminder.title;
          _selectedDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
          _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
          _selectedRepeat = reminder.repeat;
          _selectedSnooze = reminder.snooze;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Reminder not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading reminder: $e');
    }
  }

  Future<void> _updateReminder() async {
    if (_reminder == null) return;

    try {
      final updatedReminder = _reminder!.copyWith(
        title: _titleController.text.trim(),
        dateTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        repeat: _selectedRepeat,
        snooze: _selectedSnooze,
        updatedAt: DateTime.now(),
      );

      final success = await ReminderService.updateReminder(updatedReminder);
      if (success) {
        setState(() {
          _reminder = updatedReminder;
          _isEditing = false;
        });
        _showSuccessSnackBar('Reminder updated successfully');
      } else {
        _showErrorSnackBar('Failed to update reminder');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating reminder: $e');
    }
  }

  Future<void> _deleteReminder() async {
    if (_reminder == null) return;

    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      final success = await ReminderService.deleteReminder(_reminder!.id!);
      if (success) {
        _showSuccessSnackBar('Reminder deleted successfully');
        Navigator.pop(context, true); // Return true to indicate deletion
      } else {
        _showErrorSnackBar('Failed to delete reminder');
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting reminder: $e');
    }
  }

  Future<void> _completeReminder() async {
    if (_reminder == null) return;

    try {
      final success = await ReminderService.markCompleted(_reminder!.id!);
      if (success) {
        setState(() {
          _reminder = _reminder!.copyWith(
            isCompleted: true,
            completedAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
        _showSuccessSnackBar('Reminder marked as completed');
      } else {
        _showErrorSnackBar('Failed to complete reminder');
      }
    } catch (e) {
      _showErrorSnackBar('Error completing reminder: $e');
    }
  }

  Future<void> _postponeReminder() async {
    if (_reminder == null) return;

    final newTime = await _showPostponeDialog();
    if (newTime == null) return;

    try {
      final updatedReminder = _reminder!.copyWith(
        dateTime: newTime,
        updatedAt: DateTime.now(),
      );

      final success = await ReminderService.updateReminder(updatedReminder);
      if (success) {
        setState(() {
          _reminder = updatedReminder;
          _selectedDate = DateTime(newTime.year, newTime.month, newTime.day);
          _selectedTime = TimeOfDay.fromDateTime(newTime);
        });
        _showSuccessSnackBar('Reminder postponed successfully');
      } else {
        _showErrorSnackBar('Failed to postpone reminder');
      }
    } catch (e) {
      _showErrorSnackBar('Error postponing reminder: $e');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Reminder',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this reminder? This action cannot be undone.',
          style: GoogleFonts.roboto(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.roboto(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<DateTime?> _showPostponeDialog() async {
    DateTime selectedDate = _reminder?.dateTime ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    final newDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null) return null;

    final newTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (newTime == null) return null;

    return DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTime.hour,
      newTime.minute,
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Loading...',
            style: GoogleFonts.roboto(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reminder == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Reminder Not Found',
            style: GoogleFonts.roboto(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Reminder not found',
            style: GoogleFonts.roboto(color: AppColors.secondaryText),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reminder Details',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primaryText),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _updateReminder,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
                _loadReminder(); // Reload original data
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _reminder!.isCompleted ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _reminder!.isCompleted ? 'Completed' : 'Pending',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Title Field
            _buildEditableField(
              label: 'Title',
              value: _reminder!.title,
              icon: Icons.title,
              isEditable: _isEditing,
              controller: _titleController,
            ),
            
            const SizedBox(height: 20),
            
            // Date and Time
            Row(
              children: [
                Expanded(
                  child: _buildEditableField(
                    label: 'Date',
                    value: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    icon: Icons.calendar_today,
                    isEditable: _isEditing,
                    onTap: _isEditing ? _selectDate : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEditableField(
                    label: 'Time',
                    value: '${_selectedTime.format(context)}',
                    icon: Icons.access_time,
                    isEditable: _isEditing,
                    onTap: _isEditing ? _selectTime : null,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Repeat and Snooze
            Row(
              children: [
                Expanded(
                  child: _buildInfoField(
                    label: 'Repeat',
                    value: _reminder!.repeat,
                    icon: Icons.repeat,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField(
                    label: 'Snooze',
                    value: _reminder!.snooze,
                    icon: Icons.snooze,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Source and Created Info
            _buildInfoField(
              label: 'Source',
              value: _reminder!.source,
              icon: _reminder!.source == 'Voice' ? Icons.mic : Icons.edit,
            ),
            
            const SizedBox(height: 10),
            
            _buildInfoField(
              label: 'Created',
              value: '${_reminder!.createdAt.day}/${_reminder!.createdAt.month}/${_reminder!.createdAt.year}',
              icon: Icons.calendar_today,
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            if (!_reminder!.isCompleted) ...[
              _buildActionButton(
                title: 'Mark as Completed',
                icon: Icons.check_circle,
                color: Colors.green,
                onTap: _completeReminder,
              ),
              
              const SizedBox(height: 12),
              
              _buildActionButton(
                title: 'Postpone',
                icon: Icons.schedule,
                color: Colors.orange,
                onTap: _postponeReminder,
              ),
              
              const SizedBox(height: 12),

              _buildActionButton(
                title: 'Email me this reminder',
                icon: Icons.email,
                color: AppColors.confirmButton,
                onTap: () async {
                  final ok = await EmailService.sendReminderEmailViaDevice(_reminder!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Email composer opened'
                            : 'Could not open email composer (no email account?)',
                        style: GoogleFonts.roboto(color: Colors.white),
                      ),
                      backgroundColor: ok ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 12),
            ],
            
            _buildActionButton(
              title: 'Delete Reminder',
              icon: Icons.delete,
              color: Colors.red,
              onTap: _deleteReminder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required IconData icon,
    required bool isEditable,
    TextEditingController? controller,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isEditable ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEditable ? AppColors.inputBorder : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondaryText, size: 20),
                const SizedBox(width: 12),
                if (isEditable && controller != null)
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: GoogleFonts.roboto(color: AppColors.primaryText),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      value,
                      style: GoogleFonts.roboto(
                        color: AppColors.primaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (isEditable && onTap != null)
                  Icon(Icons.arrow_drop_down, color: AppColors.secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.secondaryText, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.roboto(
                    color: AppColors.primaryText,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}