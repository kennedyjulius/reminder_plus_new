import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'apple_auth_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Configure GoogleSignIn with serverClientId for Firebase Auth
  // The serverClientId is the Web client ID from Firebase Console
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Authentication Methods
  static User? get currentUser => _auth.currentUser;
  
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Initiating Google Sign-In...');
      
      // First, try to sign out any existing session to ensure fresh sign-in
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Note: Could not sign out previous session: $e');
      }
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Google Sign-In cancelled by user');
        return null;
      }

      print('✅ Google account selected: ${googleUser.email}');
      print('🔐 Requesting authentication tokens...');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('📋 Token status:');
      print('   - Access Token: ${googleAuth.accessToken != null ? "✅ Present" : "❌ Missing"}');
      print('   - ID Token: ${googleAuth.idToken != null ? "✅ Present" : "❌ Missing"}');
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ Google Sign-In failed: Missing access token or ID token');
        print('');
        print('⚠️ This usually means:');
        print('   1. OAuth client IDs are not configured in Firebase Console');
        print('   2. SHA-1 certificate fingerprint not added to Firebase Console');
        print('   3. Package name mismatch in Firebase Console');
        print('');
        print('📝 To fix:');
        print('   1. Go to Firebase Console → Project Settings → Your Android App');
        print('   2. Add SHA-1 fingerprint: 31:9F:62:2D:4C:17:B8:CE:02:D7:9B:AE:A3:8D:E7:B6:48:EF:C5:D6');
        print('   3. Ensure OAuth client IDs are configured (Web client ID should be present)');
        print('   4. Download updated google-services.json and replace the current one');
        print('   5. Ensure package name matches: com.reminder.reminderplus');
        return null;
      }

      print('🔐 Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔐 Signing in with Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);
      print('✅ Firebase authentication successful');
      print('   User ID: ${userCredential.user?.uid}');
      print('   Email: ${userCredential.user?.email}');
      
      // Create user document if it doesn't exist
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
        print('✅ New user document created');
      }
      
      return userCredential;
    } catch (e, stackTrace) {
      print('❌ Error signing in with Google: $e');
      print('Stack trace: $stackTrace');
      
      // Provide helpful error messages for common issues
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('apiexception: 10') || errorString.contains('10:')) {
        print('');
        print('⚠️ DEVELOPER_ERROR (10): OAuth configuration issue');
        print('');
        print('📝 Required fixes in Firebase Console:');
        print('   1. Go to Firebase Console → Project Settings → Your Android App');
        print('   2. Add SHA-1 fingerprint: 31:9F:62:2D:4C:17:B8:CE:02:D7:9B:AE:A3:8D:E7:B6:48:EF:C5:D6');
        print('   3. Ensure "Web client ID" is configured (needed for Firebase Auth)');
        print('   4. Download updated google-services.json');
        print('   5. Replace android/app/google-services.json with the new file');
        print('   6. Rebuild the app');
      } else if (errorString.contains('network') || errorString.contains('socket')) {
        print('⚠️ Network error: Check your internet connection');
      } else if (errorString.contains('sign_in_cancelled') || errorString.contains('cancelled')) {
        print('ℹ️ Sign-in was cancelled by user');
      } else if (errorString.contains('invalid_credential') || errorString.contains('invalid')) {
        print('⚠️ Invalid credential: OAuth client ID may be misconfigured');
        print('   Check Firebase Console → Authentication → Sign-in method → Google');
      } else {
        print('⚠️ Unknown error: Please check Firebase Console configuration');
      }
      
      return null;
    }
  }

  // Sign in with Apple
  static Future<UserCredential?> signInWithApple() async {
    try {
      final credential = await AppleAuthService.signInWithApple();
      if (credential == null) {
        print('Apple credential is null - user may have cancelled or credentials not available');
        return null;
      }

      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        print('User object is null after signing in with Apple');
        return null;
      }
      
      // Create user document if it doesn't exist
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Exception during Apple Sign-In: Code: ${e.code}, Message: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error signing in with Apple: $e');
      return null;
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print('Error signing in with email: $e');
      return null;
    }
  }

  // Create account with email and password
  static Future<UserCredential?> createAccountWithEmail(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // Update display name
      await userCredential.user?.updateDisplayName(name);
      
      // Create user document
      await _createUserDocument(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      print('Error creating account: $e');
      return null;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  // Create user document in Firestore
  static Future<void> _createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  // Update user last login
  static Future<void> updateLastLogin() async {
    final user = currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating last login: $e');
      }
    }
  }

  // Get user profile
  static Future<DocumentSnapshot?> getUserProfile() async {
    final user = currentUser;
    if (user != null) {
      try {
        return await _firestore.collection('users').doc(user.uid).get();
      } catch (e) {
        print('Error getting user profile: $e');
        return null;
      }
    }
    return null;
  }

  // Firestore Collections
  static CollectionReference get remindersCollection => 
      _firestore.collection('reminders');
  
  static CollectionReference get usersCollection => 
      _firestore.collection('users');

  // Get user's reminders stream
  static Stream<QuerySnapshot> getUserReminders() {
    final user = currentUser;
    if (user != null) {
      return remindersCollection
          .where('userId', isEqualTo: user.uid)
          .orderBy('scheduledTime', descending: false)
          .snapshots();
    }
    return const Stream.empty();
  }

  // Add reminder
  static Future<String?> addReminder(Map<String, dynamic> reminderData) async {
    final user = currentUser;
    if (user != null) {
      try {
        final docRef = await remindersCollection.add({
          ...reminderData,
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      } catch (e) {
        print('Error adding reminder: $e');
        return null;
      }
    }
    return null;
  }

  // Update reminder
  static Future<bool> updateReminder(String reminderId, Map<String, dynamic> updates) async {
    try {
      await remindersCollection.doc(reminderId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating reminder: $e');
      return false;
    }
  }

  // Delete reminder
  static Future<bool> deleteReminder(String reminderId) async {
    try {
      await remindersCollection.doc(reminderId).delete();
      return true;
    } catch (e) {
      print('Error deleting reminder: $e');
      return false;
    }
  }

  // Mark reminder as completed
  static Future<bool> markReminderCompleted(String reminderId) async {
    try {
      await remindersCollection.doc(reminderId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking reminder completed: $e');
      return false;
    }
  }
}
