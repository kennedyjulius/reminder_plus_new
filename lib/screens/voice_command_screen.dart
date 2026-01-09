import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/colors.dart';
import '../services/tts_service.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  String _recognizedText = '';
  String _status = 'Tap the microphone to start';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize(
      onStatus: (status) {
        setState(() {
          _status = status;
        });
      },
      onError: (error) {
        setState(() {
          _status = 'Error: ${error.errorMsg}';
          _isListening = false;
        });
      },
    );

    setState(() {
      _isInitialized = available;
      if (!available) {
        _status = 'Speech recognition not available';
      }
    });
  }

  Future<void> _toggleListening() async {
    if (!_isInitialized) return;

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          // Handle sound level changes if needed
        },
      );
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
    }
  }

  Future<void> _processCommand() async {
    if (_recognizedText.isEmpty) {
      _showErrorSnackBar('No speech recognized. Please try again.');
      return;
    }

    // Simple command processing
    String command = _recognizedText.toLowerCase();
    
    if (command.contains('remind me') || command.contains('reminder')) {
      // Stop listening before navigating
      if (_isListening) {
        await _speech.stop();
        setState(() {
          _isListening = false;
        });
      }
      
      // Navigate to add reminder screen with the text
      Navigator.pushNamed(
        context,
        '/add-reminder',
        arguments: {'text': _recognizedText},
      );
    } else if (command.contains('home')) {
      Navigator.pop(context);
    } else if (command.contains('settings')) {
      Navigator.pushNamed(context, '/settings');
    } else {
      // Default: navigate to add reminder with the recognized text
      // Stop listening before navigating
      if (_isListening) {
        await _speech.stop();
        setState(() {
          _isListening = false;
        });
      }
      
      Navigator.pushNamed(
        context,
        '/add-reminder',
        arguments: {'text': _recognizedText},
      );
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // App Bar
              Row(
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
                      'Voice Command',
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
              
              const SizedBox(height: 60),
              
              // Microphone Button
              GestureDetector(
                onTap: _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening 
                        ? const LinearGradient(
                            colors: [AppColors.voiceCommandStart, AppColors.voiceCommandEnd],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : const LinearGradient(
                            colors: [AppColors.iconGradientStart, AppColors.iconGradientEnd],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: AppColors.voiceCommandStart.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 80,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Status Text
              Text(
                _status,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: _isListening ? AppColors.voiceCommandStart : AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 30),
              
              // Recognized Text
              if (_recognizedText.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.inputBorder.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _recognizedText,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: AppColors.primaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Process Command Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _recognizedText.isNotEmpty ? _processCommand : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.confirmButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Process Command',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Help Text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Voice Commands',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• "Remind me to..." - Create a reminder\n'
                      '• "Home" - Go to home screen\n'
                      '• "Settings" - Open settings',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
