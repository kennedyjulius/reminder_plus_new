import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../services/gmail_parser_service.dart';
import '../services/outlook_parser_service.dart';
import '../services/email_parsing_service.dart';

class EmailParsingScreen extends StatefulWidget {
  const EmailParsingScreen({super.key});

  @override
  State<EmailParsingScreen> createState() => _EmailParsingScreenState();
}

class _EmailParsingScreenState extends State<EmailParsingScreen> {
  bool _isLoading = false;
  bool _isGmailConnected = false;
  bool _isOutlookConnected = false;
  List<Map<String, dynamic>> _parsedEvents = [];

  @override
  void initState() {
    super.initState();
    _checkExistingConnections();
  }

  Future<void> _checkExistingConnections() async {
    // Check if user has existing OAuth tokens
    try {
      final gmailConnected = await EmailParsingService.isGmailConnected();
      final outlookConnected = await EmailParsingService.isOutlookConnected();
      
      setState(() {
        _isGmailConnected = gmailConnected;
        _isOutlookConnected = outlookConnected;
      });
    } catch (e) {
      print('Error checking existing connections: $e');
      setState(() {
        _isGmailConnected = false;
        _isOutlookConnected = false;
      });
    }
  }

  Future<void> _connectGmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await GmailParserService.authenticate();
      if (success) {
        setState(() {
          _isGmailConnected = true;
        });
        _showSuccessSnackBar('Gmail connected successfully!');
      } else {
        _showErrorSnackBar('Failed to connect Gmail');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting Gmail: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connectOutlook() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await OutlookParserService.authenticate();
      if (success) {
        setState(() {
          _isOutlookConnected = true;
        });
        _showSuccessSnackBar('Outlook connected successfully!');
      } else {
        _showErrorSnackBar('Failed to connect Outlook');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting Outlook: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _parseEmails() async {
    if (!_isGmailConnected && !_isOutlookConnected) {
      _showErrorSnackBar('Please connect an email account first');
      return;
    }

    setState(() {
      _isLoading = true;
      _parsedEvents.clear();
    });

    try {
      List<Map<String, dynamic>> events = [];

      if (_isGmailConnected) {
        final gmailEvents = await GmailParserService.parseMeetingEmails();
        events.addAll(gmailEvents);
      }

      if (_isOutlookConnected) {
        final outlookEvents = await OutlookParserService.parseMeetingEmails();
        events.addAll(outlookEvents);
      }

      setState(() {
        _parsedEvents = events;
      });

      if (events.isNotEmpty) {
        _showSuccessSnackBar('Found ${events.length} meeting events!');
      } else {
        _showInfoSnackBar('No meeting events found in your emails');
      }
    } catch (e) {
      _showErrorSnackBar('Error parsing emails: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAllEvents() async {
    if (_parsedEvents.isEmpty) {
      _showErrorSnackBar('No events to save');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int savedCount = 0;
      for (final event in _parsedEvents) {
        final success = await EmailParsingService.saveParsedEvent(event);
        if (success) savedCount++;
      }

      setState(() {
        _parsedEvents.clear();
      });

      _showSuccessSnackBar('Successfully saved $savedCount events!');
    } catch (e) {
      _showErrorSnackBar('Error saving events: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editEvent(Map<String, dynamic> event, int index) async {
    // Parse the event time
    DateTime eventDateTime;
    try {
      eventDateTime = event['time'] is String 
          ? DateTime.parse(event['time']) 
          : event['time'];
    } catch (e) {
      eventDateTime = DateTime.now().add(const Duration(days: 1));
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditEventDialog(
        event: event,
        eventDateTime: eventDateTime,
      ),
    );

    if (result != null) {
      setState(() {
        _parsedEvents[index] = result;
      });
      _showSuccessSnackBar('Event updated!');
    }
  }

  Future<void> _saveEvent(Map<String, dynamic> event) async {
    try {
      print('🔄 Starting save event process...');
      print('Event data keys: ${event.keys.toList()}');
      print('Event title: ${event['title']}');
      print('Event time: ${event['time']} (${event['time'].runtimeType})');
      print('Event source: ${event['source']}');
      
      // Validate event data before saving
      if (event['title'] == null || event['title'].toString().trim().isEmpty) {
        _showErrorSnackBar('Event title is required');
        return;
      }
      
      if (event['time'] == null) {
        _showErrorSnackBar('Event time is required');
        return;
      }
      
      setState(() => _isLoading = true);
      
      final success = await EmailParsingService.saveParsedEvent(event);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (success) {
          setState(() {
            _parsedEvents.remove(event);
          });
          _showSuccessSnackBar('Event saved successfully as reminder!');
        } else {
          _showErrorSnackBar('Failed to save event. Please check console logs for details.');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _saveEvent: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error saving event: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Email Events',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          if (_parsedEvents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save, color: AppColors.primaryText),
              onPressed: _saveAllEvents,
              tooltip: 'Save All Events',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Connect your email accounts to automatically extract meeting events',
                    style: GoogleFonts.roboto(
                      color: AppColors.secondaryText,
                      fontSize: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Email Account Connections
                  _buildSectionTitle('Email Accounts'),
                  
                  const SizedBox(height: 16),
                  
                  // Gmail Connection
                  _buildConnectionCard(
                    title: 'Gmail',
                    subtitle: 'Connect your Google account',
                    icon: Icons.mail,
                    isConnected: _isGmailConnected,
                    onTap: _isGmailConnected ? null : _connectGmail,
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Outlook Connection
                  _buildConnectionCard(
                    title: 'Microsoft Outlook',
                    subtitle: 'Connect your Microsoft account',
                    icon: Icons.mail_outline,
                    isConnected: _isOutlookConnected,
                    onTap: _isOutlookConnected ? null : _connectOutlook,
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Parse Button
                  if (_isGmailConnected || _isOutlookConnected) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _parseEmails,
                        icon: const Icon(Icons.search, color: Colors.white),
                        label: Text(
                          'Parse Email Events',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.confirmButton,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                  
                  // Parsed Events
                  if (_parsedEvents.isNotEmpty) ...[
                    _buildSectionTitle('Found Events (${_parsedEvents.length})'),
                    
                    const SizedBox(height: 16),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _parsedEvents.length,
                      itemBuilder: (context, index) {
                        final event = _parsedEvents[index];
                        return _buildEventCard(event, index);
                      },
                    ),
                  ],
                  
                  // Empty State
                  if (_parsedEvents.isEmpty && (_isGmailConnected || _isOutlookConnected)) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_note_outlined,
                              color: AppColors.secondaryText,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: GoogleFonts.roboto(
                                color: AppColors.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Parse Email Events" to scan your emails for meetings',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.roboto(
        color: AppColors.primaryText,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildConnectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isConnected,
    required VoidCallback? onTap,
    required LinearGradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConnected ? Colors.green : AppColors.inputBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
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
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Connected',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.secondaryText,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: event['source'] == 'Gmail' ? Colors.red : Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.event,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? 'Untitled Event',
                      style: GoogleFonts.roboto(
                        color: AppColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event['source']} • ${_formatDateTime(event['time'])}',
                      style: GoogleFonts.roboto(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editEvent(event, index),
                    icon: const Icon(Icons.edit, color: AppColors.confirmButton),
                    tooltip: 'Edit Event',
                  ),
                  IconButton(
                    onPressed: () => _saveEvent(event),
                    icon: const Icon(Icons.save, color: Colors.green),
                    tooltip: 'Save Event',
                  ),
                ],
              ),
            ],
          ),
          
          if (event['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              event['description'],
              style: GoogleFonts.roboto(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
          
          if (event['location'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppColors.secondaryText,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  event['location'],
                  style: GoogleFonts.roboto(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'No date';
    
    try {
      final DateTime dt = dateTime is String ? DateTime.parse(dateTime) : dateTime;
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
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

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// Edit Event Dialog
class _EditEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  final DateTime eventDateTime;

  const _EditEventDialog({
    required this.event,
    required this.eventDateTime,
  });

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event['title'] ?? '');
    _locationController = TextEditingController(text: widget.event['location'] ?? '');
    _descriptionController = TextEditingController(text: widget.event['description'] ?? '');
    _selectedDate = DateTime(
      widget.eventDateTime.year,
      widget.eventDateTime.month,
      widget.eventDateTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(widget.eventDateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _saveChanges() {
    final updatedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final updatedEvent = Map<String, dynamic>.from(widget.event);
    updatedEvent['title'] = _titleController.text.trim();
    updatedEvent['location'] = _locationController.text.trim().isEmpty 
        ? null 
        : _locationController.text.trim();
    updatedEvent['description'] = _descriptionController.text.trim();
    updatedEvent['time'] = updatedDateTime.toIso8601String();

    Navigator.of(context).pop(updatedEvent);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.edit,
                    color: AppColors.confirmButton,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Event',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.secondaryText),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Title Field
              Text(
                'Title',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: GoogleFonts.roboto(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: 'Event title',
                  hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Date & Time
              Text(
                'Date & Time',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, 
                              color: AppColors.secondaryText, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _formatDate(_selectedDate),
                              style: GoogleFonts.roboto(
                                color: AppColors.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, 
                              color: AppColors.secondaryText, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _formatTime(_selectedTime),
                              style: GoogleFonts.roboto(
                                color: AppColors.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Location Field
              Text(
                'Location',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                style: GoogleFonts.roboto(color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: 'Event location',
                  hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.location_on, 
                    color: AppColors.secondaryText),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Description Field
              Text(
                'Description',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                style: GoogleFonts.roboto(color: AppColors.primaryText),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Event description',
                  hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.inputBackground,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.confirmButton,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Changes',
                        style: GoogleFonts.roboto(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
