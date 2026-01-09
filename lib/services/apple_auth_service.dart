import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppleAuthService {
  static final AppleAuthService _instance = AppleAuthService._internal();
  
  factory AppleAuthService() => _instance;
  AppleAuthService._internal();

  /// Check if Apple Sign-In is available (iOS 13+)
  static bool get isAvailable => Platform.isIOS;

  /// Sign in with Apple
  static Future<AuthCredential?> signInWithApple() async {
    try {
      if (!isAvailable) {
        print('Apple Sign-In is not available on this platform');
        return null;
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (appleCredential.identityToken == null) {
        print('Error: Identity token is null from Apple Sign-In');
        return null;
      }

      // Create a new credential from the response.
      // Only use identityToken for Firebase authentication
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode ?? appleCredential.identityToken,
      );

      return oauthCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        print('User cancelled Apple Sign-In');
      } else {
        print('Apple Sign-In authorization error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('Error signing in with Apple: $e');
      return null;
    }
  }

  /// Extract user email from Apple credential
  static String? getEmailFromAppleCredential(
    AuthorizationCredentialAppleID appleCredential,
  ) {
    return appleCredential.email;
  }

  /// Extract full name from Apple credential
  static String? getFullNameFromAppleCredential(
    AuthorizationCredentialAppleID appleCredential,
  ) {
    final givenName = appleCredential.givenName ?? '';
    final familyName = appleCredential.familyName ?? '';
    return '$givenName $familyName'.trim();
  }
}
