import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      print('TTS: Starting initialization...');
      
      // Set up error handler first
      _tts.setErrorHandler((msg) {
        print('TTS Error: $msg');
      });
      
      // Set language with timeout
      print('TTS: Setting language...');
      await _tts.setLanguage("en-US").timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('TTS: Language setting timed out');
        },
      );
      
      // Set speech rate with timeout
      print('TTS: Setting speech rate...');
      await _tts.setSpeechRate(0.5).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('TTS: Speech rate setting timed out');
        },
      );
      
      // Set volume with timeout
      print('TTS: Setting volume...');
      await _tts.setVolume(0.8).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('TTS: Volume setting timed out');
        },
      );
      
      // Set pitch with timeout
      print('TTS: Setting pitch...');
      await _tts.setPitch(1.0).timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('TTS: Pitch setting timed out');
        },
      );

      _initialized = true;
      print('TTS: Initialization completed successfully');
    } catch (e) {
      print('TTS: Initialization error: $e');
      // Mark as initialized anyway to prevent blocking
      _initialized = true;
    }
  }

  // Speak text
  static Future<void> speak(String text) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      await _tts.speak(text);
    } catch (e) {
      print('Error speaking text: $e');
    }
  }

  // Stop speaking
  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }
  }

  // Pause speaking
  static Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      print('Error pausing TTS: $e');
    }
  }

  // Set speech rate (0.0 to 1.0)
  static Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      print('Error setting speech rate: $e');
    }
  }

  // Set volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    try {
      await _tts.setVolume(volume);
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  // Set pitch (0.5 to 2.0)
  static Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      print('Error setting pitch: $e');
    }
  }

  // Get available languages
  static Future<List<dynamic>> getLanguages() async {
    try {
      return await _tts.getLanguages;
    } catch (e) {
      print('Error getting languages: $e');
      return [];
    }
  }

  // Set language
  static Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  // Check if TTS is speaking (Note: This method may not be available on all platforms)
  static Future<bool> isSpeaking() async {
    try {
      // Note: isSpeaking is not available in all versions of flutter_tts
      // This is a placeholder implementation
      return false;
    } catch (e) {
      print('Error checking if speaking: $e');
      return false;
    }
  }
}
