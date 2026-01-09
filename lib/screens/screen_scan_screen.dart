import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';

class ScreenScanScreen extends StatefulWidget {
  const ScreenScanScreen({super.key});

  @override
  State<ScreenScanScreen> createState() => _ScreenScanScreenState();
}

class _ScreenScanScreenState extends State<ScreenScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _isExtracting = false;
  
  // Parsed data
  String? _eventTitle;
  DateTime? _eventDateTime;
  String? _eventDescription;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Screen Scan',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Scan Your Screen',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture a photo of your desktop screen to extract event information',
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // Image capture section
            if (_selectedImage == null) ...[
              _buildImageCaptureSection(),
            ] else ...[
              _buildImagePreviewSection(),
            ],
            
            const SizedBox(height: 30),
            
            // Processing section
            if (_isProcessing || _isExtracting) ...[
              _buildProcessingSection(),
            ],
            
            // Extracted text section
            if (_extractedText.isNotEmpty) ...[
              _buildExtractedTextSection(),
            ],
            
            // Event preview section
            if (_eventTitle != null && _eventDateTime != null) ...[
              _buildEventPreviewSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCaptureSection() {
    return Container(
      height: 220, // Increased height to prevent overflow
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.screenScanSolid.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Add padding for better spacing
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_outlined,
              size: 56, // Slightly smaller icon
              color: AppColors.screenScanSolid,
            ),
            const SizedBox(height: 12), // Reduced spacing
            Text(
              'Choose Image Source',
              style: GoogleFonts.roboto(
                fontSize: 16, // Slightly smaller font
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 6), // Reduced spacing
            Text(
              'Take a photo or select from gallery',
              style: GoogleFonts.roboto(
                fontSize: 13, // Slightly smaller font
                color: AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16), // Reduced spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  label: Text(
                    'Camera',
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.screenScanSolid,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced padding
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                  label: Text(
                    'Gallery',
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.screenScanSolid,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced padding
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewSection() {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.screenScanSolid.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _processImage,
              icon: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_fix_high, color: Colors.white),
              label: Text(
                _isProcessing ? 'Processing...' : 'Extract Text',
                style: GoogleFonts.roboto(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.screenScanSolid,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _retakeImage,
              icon: const Icon(Icons.refresh, color: AppColors.screenScanSolid),
              label: Text(
                'Retake',
                style: GoogleFonts.roboto(color: AppColors.screenScanSolid),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: BorderSide(color: AppColors.screenScanSolid),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.screenScanSolid),
          ),
          const SizedBox(height: 16),
          Text(
            _isExtracting ? 'Extracting text from image...' : 'Processing image...',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extracted Text:',
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Text(
              _extractedText,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.primaryText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.screenScanSolid.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                color: AppColors.screenScanSolid,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Event Preview',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Event title
          _buildPreviewItem(
            'Title',
            _eventTitle!,
            Icons.title,
          ),
          
          const SizedBox(height: 12),
          
          // Event date/time
          _buildPreviewItem(
            'Date & Time',
            DateFormat('MMM dd, yyyy • hh:mm a').format(_eventDateTime!),
            Icons.schedule,
          ),
          
          if (_eventDescription != null && _eventDescription!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPreviewItem(
              'Description',
              _eventDescription!,
              Icons.description,
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveEvent,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    'Save Reminder',
                    style: GoogleFonts.roboto(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.screenScanSolid,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editEvent,
                  icon: const Icon(Icons.edit, color: AppColors.screenScanSolid),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.roboto(color: AppColors.screenScanSolid),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.screenScanSolid),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.secondaryText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedText = '';
          _eventTitle = null;
          _eventDateTime = null;
          _eventDescription = null;
        });
      }
    } catch (e) {
      print('Camera error: $e');
      _showErrorSnackBar('Error taking photo: ${e.toString()}');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _extractedText = '';
          _eventTitle = null;
          _eventDateTime = null;
          _eventDescription = null;
        });
      }
    } catch (e) {
      print('Gallery error: $e');
      _showErrorSnackBar('Error selecting image: ${e.toString()}');
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Extract text using Google ML Kit
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false;
        _isExtracting = true;
      });

      // Parse the extracted text
      await _parseExtractedText();
      
      setState(() {
        _isExtracting = false;
      });

      await textRecognizer.close();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isExtracting = false;
      });
      _showErrorSnackBar('Error processing image: $e');
    }
  }

  Future<void> _parseExtractedText() async {
    if (_extractedText.isEmpty) return;

    // Parse date and time patterns
    final dateTimePatterns = [
      // MM/DD/YYYY HH:MM AM/PM
      RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
      // MM-DD-YYYY HH:MM AM/PM
      RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
      // Month DD, YYYY HH:MM AM/PM
      RegExp(r'([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
      // Today/Tomorrow with time
      RegExp(r'(today|tomorrow)\s+(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
      // Just time (assume today)
      RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false),
    ];

    DateTime? parsedDateTime;
    String? eventTitle;
    String? eventDescription;

    // Try to find date/time patterns
    for (final pattern in dateTimePatterns) {
      final match = pattern.firstMatch(_extractedText);
      if (match != null) {
        parsedDateTime = _parseDateTimeFromMatch(match);
        if (parsedDateTime != null) break;
      }
    }

    // Extract event title (usually the first line or before the date/time)
    final lines = _extractedText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      eventTitle = lines.first.trim();
      
      // If we found a date/time, try to get title from before it
      if (parsedDateTime != null) {
        final dateTimeIndex = _extractedText.toLowerCase().indexOf(parsedDateTime.toString().toLowerCase());
        if (dateTimeIndex > 0) {
          final beforeDateTime = _extractedText.substring(0, dateTimeIndex).trim();
          if (beforeDateTime.isNotEmpty) {
            eventTitle = beforeDateTime.split('\n').last.trim();
          }
        }
      }
    }

    // Extract description (remaining text after title and date/time)
    if (eventTitle != null) {
      String description = _extractedText;
      if (eventTitle.isNotEmpty) {
        description = description.replaceFirst(eventTitle, '').trim();
      }
      if (parsedDateTime != null) {
        final dateTimeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(parsedDateTime);
        description = description.replaceFirst(dateTimeStr, '').trim();
      }
      if (description.isNotEmpty && description != eventTitle) {
        eventDescription = description;
      }
    }

    setState(() {
      _eventTitle = eventTitle ?? 'Untitled Event';
      _eventDateTime = parsedDateTime ?? DateTime.now().add(const Duration(hours: 1));
      _eventDescription = eventDescription;
    });
  }

  DateTime? _parseDateTimeFromMatch(RegExpMatch match) {
    try {
      // Handle different patterns based on the number of groups
      if (match.groupCount >= 6) {
        // MM/DD/YYYY or MM-DD-YYYY format
        final month = int.parse(match.group(1)!);
        final day = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        final hour = int.parse(match.group(4)!);
        final minute = int.parse(match.group(5)!);
        final isPM = match.group(6)!.toUpperCase() == 'PM';
        
        return DateTime(
          year,
          month,
          day,
          isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour),
          minute,
        );
      } else if (match.groupCount >= 4) {
        final firstGroup = match.group(1)!;
        if (firstGroup.toLowerCase() == 'today' || firstGroup.toLowerCase() == 'tomorrow') {
          // Today/Tomorrow format
          final isTomorrow = firstGroup.toLowerCase() == 'tomorrow';
          final hour = int.parse(match.group(2)!);
          final minute = int.parse(match.group(3)!);
          final isPM = match.group(4)!.toUpperCase() == 'PM';
          
          final now = DateTime.now();
          final targetDate = isTomorrow ? now.add(const Duration(days: 1)) : now;
          
          return DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour),
            minute,
          );
        }
      } else if (match.groupCount >= 3) {
        // Just time format (assume today)
        final hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final isPM = match.group(3)!.toUpperCase() == 'PM';
        
        final now = DateTime.now();
        return DateTime(
          now.year,
          now.month,
          now.day,
          isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour),
          minute,
        );
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return null;
  }

  Future<void> _saveEvent() async {
    if (_eventTitle == null || _eventDateTime == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      print('Starting OCR reminder save process...');
      print('Event Title: $_eventTitle');
      print('Event DateTime: $_eventDateTime');
      print('Event Description: $_eventDescription');

      // Create reminder model using the same structure as manual reminders
      final reminder = ReminderModel(
        title: _eventTitle!,
        dateTime: _eventDateTime!,
        repeat: 'No Repeat',
        snooze: '5 Min',
        createdBy: user.uid,
        source: 'ocr',
        metadata: {
          'description': _eventDescription,
          'extractedText': _extractedText,
          'imagePath': _selectedImage?.path,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('Reminder model created, calling ReminderService.saveReminder...');
      
      // Use ReminderService to save (same as manual reminders)
      final reminderId = await ReminderService.saveReminder(reminder);
      
      print('ReminderService.saveReminder returned: $reminderId');
      
      if (reminderId != null) {
        // Save OCR scan for analytics (optional - don't fail if this fails)
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('ocr_scans')
              .add({
            'extractedText': _extractedText,
            'eventTitle': _eventTitle,
            'eventDateTime': _eventDateTime,
            'eventDescription': _eventDescription,
            'imagePath': _selectedImage?.path,
            'reminderId': reminderId,
            'createdAt': DateTime.now(),
          });
          print('OCR scan data saved successfully');
        } catch (ocrError) {
          print('Warning: Failed to save OCR scan data: $ocrError');
          // Don't fail the entire operation for analytics data
        }

        _showSuccessSnackBar('Reminder saved successfully!');
        
        // Reset the form
        setState(() {
          _selectedImage = null;
          _extractedText = '';
          _eventTitle = null;
          _eventDateTime = null;
          _eventDescription = null;
        });
      } else {
        _showErrorSnackBar('Failed to save reminder. Please try again.');
      }
    } catch (e) {
      print('Error saving OCR reminder: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      _showErrorSnackBar('Error saving reminder: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _editEvent() {
    if (_eventTitle == null || _eventDateTime == null) return;
    
    showDialog(
      context: context,
      builder: (context) => _EditEventDialog(
        initialTitle: _eventTitle!,
        initialDateTime: _eventDateTime!,
        initialDescription: _eventDescription ?? '',
        onSave: (title, dateTime, description) {
          setState(() {
            _eventTitle = title;
            _eventDateTime = dateTime;
            _eventDescription = description;
          });
        },
      ),
    );
  }

  void _retakeImage() {
    setState(() {
      _selectedImage = null;
      _extractedText = '';
      _eventTitle = null;
      _eventDateTime = null;
      _eventDescription = null;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        backgroundColor: Colors.red,
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
      ),
    );
  }

}

class _EditEventDialog extends StatefulWidget {
  final String initialTitle;
  final DateTime initialDateTime;
  final String initialDescription;
  final Function(String title, DateTime dateTime, String description) onSave;

  const _EditEventDialog({
    required this.initialTitle,
    required this.initialDateTime,
    required this.initialDescription,
    required this.onSave,
  });

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _selectedDateTime = widget.initialDateTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.screenScanSolid,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.screenScanSolid,
                onPrimary: Colors.white,
                surface: AppColors.cardBackground,
                onSurface: AppColors.primaryText,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        'Edit Event',
        style: GoogleFonts.roboto(
          color: AppColors.primaryText,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title field
            TextField(
              controller: _titleController,
              style: GoogleFonts.roboto(color: AppColors.primaryText),
              decoration: InputDecoration(
                labelText: 'Event Title',
                labelStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.screenScanSolid),
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
            ),
            const SizedBox(height: 16),
            
            // Date & Time field
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.inputBorder),
                  borderRadius: BorderRadius.circular(4),
                  color: AppColors.inputBackground,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: AppColors.screenScanSolid,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(_selectedDateTime),
                      style: GoogleFonts.roboto(
                        color: AppColors.primaryText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Description field
            TextField(
              controller: _descriptionController,
              style: GoogleFonts.roboto(color: AppColors.primaryText),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.screenScanSolid),
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.roboto(color: AppColors.secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty) {
              widget.onSave(
                _titleController.text.trim(),
                _selectedDateTime,
                _descriptionController.text.trim(),
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.screenScanSolid,
          ),
          child: Text(
            'Save',
            style: GoogleFonts.roboto(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
