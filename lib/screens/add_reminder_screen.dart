import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';

class AddReminderScreen extends StatefulWidget {
  final String? initialText;
  const AddReminderScreen({super.key, this.initialText});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _customSnoozeController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedRepeat = 'No Repeat';
  String _selectedSnooze = '5 Min';
  bool _isLoading = false;
  bool _isRecording = false;
  bool _showCustomSnooze = false;
  bool _showCustomRepeat = false;
  bool _isFromVoiceInput = false;
  bool _isVoiceRecording = false; // Track if we're actively recording voice

  late stt.SpeechToText _speech;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();

    // Initialize speech in background without blocking UI
    Future.microtask(() => _initializeSpeech());

    // Check if there's initial text from voice command
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // First check widget parameter, then route arguments as fallback
      final text = widget.initialText ?? 
          (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        _parseInitialText(text);
      }
    });
  }

  Future<void> _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _isRecording = status == 'listening';
              _isVoiceRecording = status == 'listening';
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isRecording = false;
              _isVoiceRecording = false;
            });
            _showErrorSnackBar('Speech recognition error: ${error.errorMsg}');
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } catch (e) {
      print('Error initializing speech: $e');
      if (mounted) {
        setState(() {
          _speechEnabled = false;
        });
      }
    }
  }

  void _parseInitialText(String text) {
    final reminder = ReminderService.parseVoiceInput(text);
    if (reminder != null) {
      setState(() {
        _titleController.text = reminder.title;
        _selectedDate = DateTime(reminder.dateTime.year, reminder.dateTime.month, reminder.dateTime.day);
        _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
        _selectedRepeat = reminder.repeat;
        _selectedSnooze = reminder.snooze;
        _isFromVoiceInput = true;
      });
    } else {
      setState(() {
        _titleController.text = text;
        _isFromVoiceInput = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customSnoozeController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startVoiceInput() async {
    if (!_speechEnabled) {
      _showErrorSnackBar('Speech recognition not available');
      return;
    }

    try {
      // Stop any existing listening session first
      if (_isRecording) {
        await _speech.stop();
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            // Update the title with recognized words
            setState(() {
              _titleController.text = result.recognizedWords;
            });

            // Parse the voice input for date, time, repeat, and snooze details
            final reminder = ReminderService.parseVoiceInput(result.recognizedWords);
            if (reminder != null && mounted) {
              setState(() {
                // Update title with cleaned version
                _titleController.text = reminder.title;

                // Update date and time fields automatically
                _selectedDate = DateTime(
                  reminder.dateTime.year,
                  reminder.dateTime.month,
                  reminder.dateTime.day,
                );
                _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);

                // Update repeat and snooze options
                _selectedRepeat = reminder.repeat;
                _selectedSnooze = reminder.snooze;

                // Show custom fields if needed
                _showCustomRepeat = reminder.repeat == 'Custom Interval';
                _showCustomSnooze = reminder.snooze == 'Custom';

                _isFromVoiceInput = true;
              });
            } else if (mounted) {
              setState(() {
                _isFromVoiceInput = true;
              });
            }
          }
        },
        listenFor: const Duration(minutes: 5), // Extended listening time
        pauseFor: const Duration(seconds: 10), // Longer pause tolerance
        partialResults: true,
        localeId: 'en_US',
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation, // Changed to dictation mode for continuous listening
      );

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isVoiceRecording = true;
        });
      }
    } catch (e) {
      print('Error starting voice input: $e');
      _showErrorSnackBar('Error starting voice input');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isVoiceRecording = false;
        });
      }
    }
  }

  Future<void> _stopVoiceInput() async {
    try {
      await _speech.stop();

      // Keep the speech engine initialized and ready for next use
      // No need to reinitialize - just update the recording state
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isVoiceRecording = false;
        });
      }
    } catch (e) {
      print('Error stopping voice input: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isVoiceRecording = false;
        });
      }
    }
  }

  Future<void> _cancelVoiceInput() async {
    try {
      await _speech.stop();

      // Clear the current voice input
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isVoiceRecording = false;
          _titleController.clear();
          _isFromVoiceInput = false;
        });
      }

      _showSuccessSnackBar('Voice recording cancelled');
    } catch (e) {
      print('Error cancelling voice input: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isVoiceRecording = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.confirmButton,
              onPrimary: AppColors.primaryText,
              surface: AppColors.cardBackground,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.confirmButton,
              onPrimary: AppColors.primaryText,
              surface: AppColors.cardBackground,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a reminder title');
      return;
    }

    // Validate custom snooze input
    if (_selectedSnooze == 'Custom') {
      if (_customSnoozeController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter a custom snooze time');
        return;
      }

      final snoozeValue = int.tryParse(_customSnoozeController.text.trim());
      if (snoozeValue == null || snoozeValue <= 0) {
        _showErrorSnackBar('Please enter a valid number of minutes');
        return;
      }

      if (snoozeValue > 1440) { // More than 24 hours
        _showErrorSnackBar('Snooze time cannot exceed 1440 minutes (24 hours)');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Check authentication first
      final currentUser = FirebaseAuth.instance.currentUser;
      print('Current user in save: ${currentUser?.uid}');

      if (currentUser == null) {
        _showErrorSnackBar('You must be logged in to save reminders');
        return;
      }

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Process custom snooze if selected
      String finalSnooze = _selectedSnooze;
      if (_selectedSnooze == 'Custom' && _customSnoozeController.text.isNotEmpty) {
        final snoozeValue = int.parse(_customSnoozeController.text.trim());
        finalSnooze = '${snoozeValue} Min';
      }

      final reminder = ReminderModel(
        title: _titleController.text.trim(),
        dateTime: dateTime,
        repeat: _selectedRepeat,
        snooze: finalSnooze,
        createdBy: currentUser.uid,
        source: _isFromVoiceInput ? 'Voice' : 'Manual',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Attempting to save reminder: ${reminder.title}');

      // Test Firebase connection
      try {
        final firestore = FirebaseFirestore.instance;
        print('Firestore instance created successfully');

        // Test write to a test collection
        await firestore.collection('test').doc('connection_test').set({
          'timestamp': FieldValue.serverTimestamp(),
          'test': true,
        });
        print('Test write successful');

        // Clean up test document
        await firestore.collection('test').doc('connection_test').delete();
        print('Test cleanup successful');
      } catch (firebaseError) {
        print('Firebase connection test failed: $firebaseError');
      }

      final reminderId = await ReminderService.saveReminder(reminder);
      print('Save result: $reminderId');

      if (reminderId != null && mounted) {
        _showSuccessSnackBar(ReminderService.getSuccessMessage(reminder));
        Navigator.pop(context);
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          _showErrorSnackBar('You must be logged in to save reminders');
        } else {
          _showErrorSnackBar('Failed to save reminder. Please try again.');
        }
      }
    } catch (e) {
      print('Exception in _saveReminder: $e');
      print('Exception type: ${e.runtimeType}');
      _showErrorSnackBar('Error saving reminder: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, AppColors.confirmButton],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
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
                      'Add Reminder',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _saveReminder,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.primaryText,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.save,
                      color: AppColors.primaryText,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reminder Title Field
                    _buildSectionTitle('Reminder Title'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: AppColors.primaryText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Call John',
                          hintStyle: GoogleFonts.roboto(
                            color: AppColors.secondaryText,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: const Icon(
                            Icons.edit,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Voice Command Option
                    _buildSectionTitle('Voice Command'),
                    Center(
                      child: Column(
                        children: [
                          // Voice Recording Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Start/Stop Recording Button
                              GestureDetector(
                                onTap: _speechEnabled ? (_isVoiceRecording ? _stopVoiceInput : _startVoiceInput) : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: !_speechEnabled
                                        ? LinearGradient(
                                      colors: [Colors.grey.shade600, Colors.grey.shade800],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                        : _isVoiceRecording
                                        ? const LinearGradient(
                                      colors: [Colors.red, Colors.orange],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                        : const LinearGradient(
                                      colors: [AppColors.voiceCommandStart, AppColors.voiceCommandEnd],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: _isVoiceRecording
                                        ? [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                        : [
                                      BoxShadow(
                                        color: AppColors.voiceCommandStart.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    !_speechEnabled
                                        ? Icons.mic_off
                                        : _isVoiceRecording
                                        ? Icons.stop
                                        : Icons.mic,
                                    size: 40,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),

                              // Cancel Button (only show when recording)
                              if (_isVoiceRecording) ...[
                                const SizedBox(width: 20),
                                GestureDetector(
                                  onTap: _cancelVoiceInput,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.shade600,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Status Text
                          Text(
                            _isVoiceRecording
                                ? 'Recording... Tap stop when done'
                                : _speechEnabled
                                ? 'Tap microphone to start recording'
                                : 'Microphone not available',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: _isVoiceRecording ? Colors.red : AppColors.secondaryText,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Recording Instructions
                          if (_isVoiceRecording) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Speak naturally - pauses won\'t stop recording',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: Colors.red.shade300,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Say: "Remind me to visit Church on 10th November 2025 at 4 PM. Repeat the reminder every hour."',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Date & Time Picker
                    _buildSectionTitle('Date & Time'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimeField(
                            'Date',
                            _formatDate(_selectedDate),
                            Icons.calendar_today,
                            _selectDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTimeField(
                            'Time',
                            _formatTime(_selectedTime),
                            Icons.access_time,
                            _selectTime,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Repeat Options
                    _buildSectionTitle('Repeat'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedRepeat,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.repeat, color: AppColors.secondaryText),
                        ),
                        dropdownColor: AppColors.cardBackground,
                        style: GoogleFonts.roboto(color: AppColors.primaryText),
                        items: ReminderModel.repeatOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedRepeat = newValue;
                              _showCustomRepeat = newValue == 'Custom Interval';
                            });
                          }
                        },
                      ),
                    ),

                    if (_showCustomRepeat) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: TextField(
                          style: GoogleFonts.roboto(color: AppColors.primaryText),
                          decoration: InputDecoration(
                            hintText: 'Every X days (e.g., Every 3 days)',
                            hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Snooze Options
                    _buildSectionTitle('Snooze'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ReminderModel.snoozeOptions.map((snooze) {
                        final isSelected = _selectedSnooze == snooze;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSnooze = snooze;
                              _showCustomSnooze = snooze == 'Custom';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.confirmButton : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.confirmButton : AppColors.inputBorder,
                              ),
                            ),
                            child: Text(
                              snooze,
                              style: GoogleFonts.roboto(
                                color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_showCustomSnooze) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: TextField(
                          controller: _customSnoozeController,
                          style: GoogleFonts.roboto(color: AppColors.primaryText),
                          keyboardType: TextInputType.numberWithOptions(decimal: false),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter minutes (e.g., 15)',
                            hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            suffixText: 'minutes',
                            suffixStyle: GoogleFonts.roboto(
                              color: AppColors.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                          onChanged: (value) {
                            // Validate that only numbers are entered
                            if (value.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(value)) {
                              _customSnoozeController.text = value.replaceAll(RegExp(r'[^0-9]'), '');
                              _customSnoozeController.selection = TextSelection(
                                baseOffset: _customSnoozeController.text.length,
                                extentOffset: _customSnoozeController.text.length,
                              );
                            }
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveReminder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.confirmButton,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: AppColors.primaryText)
                            : Text(
                          'Save Reminder',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondaryText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDate = DateTime(date.year, date.month, date.day);

    if (reminderDate == today) {
      return 'Today';
    } else if (reminderDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
