import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();
  
  // Gmail scopes
  static const String _gmailScope = 'https://www.googleapis.com/auth/gmail.readonly';
  
  // Calendar scopes
  static const List<String> _calendarScopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar',
  ];

  final GoogleSignIn _gmailSignIn = GoogleSignIn(
    scopes: [_gmailScope],
  );

  final GoogleSignIn _calendarSignIn = GoogleSignIn(
    scopes: _calendarScopes,
  );

  // Gmail authentication
  Future<AuthClient?> authenticateGmail() async {
    try {
      print('Starting Gmail authentication...');
      final GoogleSignInAccount? account = await _gmailSignIn.signIn();
      if (account == null) {
        print('Gmail authentication cancelled by user');
        return null;
      }

      print('Gmail account selected: ${account.email}');
      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.accessToken == null) {
        print('Gmail authentication failed: No access token');
        return null;
      }

      print('Gmail authentication successful');
      return authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            auth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          auth.idToken,
          [_gmailScope],
        ),
      );
    } catch (e) {
      print('Error authenticating Gmail: $e');
      return null;
    }
  }

  // Calendar authentication
  Future<AuthClient?> authenticateCalendar() async {
    try {
      print('Starting Calendar authentication...');
      final GoogleSignInAccount? account = await _calendarSignIn.signIn();
      if (account == null) {
        print('Calendar authentication cancelled by user');
        return null;
      }

      print('Calendar account selected: ${account.email}');
      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.accessToken == null) {
        print('Calendar authentication failed: No access token');
        return null;
      }

      print('Calendar authentication successful');
      return authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            auth.accessToken!,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          auth.idToken,
          _calendarScopes,
        ),
      );
    } catch (e) {
      print('Error authenticating Calendar: $e');
      return null;
    }
  }

  // Sign out from all Google services
  Future<void> signOut() async {
    try {
      await _gmailSignIn.signOut();
      await _calendarSignIn.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Check if Gmail is connected
  bool isGmailConnected() {
    return _gmailSignIn.currentUser != null;
  }

  // Check if Calendar is connected
  bool isCalendarConnected() {
    return _calendarSignIn.currentUser != null;
  }

  // Save token to Firestore
  Future<void> saveTokenToFirestore(String service, String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(service)
          .set({
        'token': token,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  // Get token from Firestore
  Future<String?> getTokenFromFirestore(String service) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(service)
          .get();

      return doc.data()?['token'];
    } catch (e) {
      print('Error getting token from Firestore: $e');
      return null;
    }
  }
}
