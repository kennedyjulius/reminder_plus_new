# OAuth Configuration Guide

## 🔐 **OAuth Setup Instructions**

This guide explains how to configure OAuth authentication for Google Sign-In and Microsoft Outlook integration in the Reminder Plus app.

---

## 📱 **iOS Configuration**

### **Info.plist URL Schemes Added**

The following URL schemes have been added to `ios/Runner/Info.plist`:

```xml
<!-- URL Schemes for OAuth Authentication -->
<key>CFBundleURLTypes</key>
<array>
    <!-- Google Sign-In URL Scheme -->
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.76730819991-pg8rtokoh5urn6d63k3hnc1ksgjt6lo9</string>
        </array>
    </dict>
    <!-- Microsoft OAuth URL Scheme -->
    <dict>
        <key>CFBundleURLName</key>
        <string>MicrosoftOAuth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.reminder.reminderplus</string>
        </array>
    </dict>
    <!-- Additional URL Scheme for app deep linking -->
    <dict>
        <key>CFBundleURLName</key>
        <string>ReminderPlus</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>reminderplus</string>
        </array>
    </dict>
</array>
```

---

## 🤖 **Android Configuration**

### **AndroidManifest.xml Intent Filters Added**

The following intent filters have been added to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Google Sign-In Intent Filter -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.googleusercontent.apps.76730819991-pg8rtokoh5urn6d63k3hnc1ksgjt6lo9" />
</intent-filter>

<!-- Microsoft OAuth Intent Filter -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.reminder.reminderplus" />
</intent-filter>

<!-- App Deep Link Intent Filter -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="reminderplus" />
</intent-filter>
```

---

## 🔧 **Code Configuration**

### **Google Sign-In Setup**

Updated `lib/services/gmail_parser_service.dart`:

```dart
static final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '76730819991-pg8rtokoh5urn6d63k3hnc1ksgjt6lo9.apps.googleusercontent.com',
  scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
);
```

### **Microsoft OAuth Setup**

Updated `lib/services/outlook_parser_service.dart`:

```dart
static const String _clientId = 'YOUR_MICROSOFT_CLIENT_ID'; // Replace with actual client ID
static const String _redirectUrl = 'com.reminder.reminderplus://auth';
static const String _scope = 'https://graph.microsoft.com/Mail.Read';
```

---

## 🛠️ **Required Setup Steps**

### **1. Google Cloud Console Setup**

1. **Create/Select Project**: Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **Enable APIs**: Enable Gmail API and Google Sign-In API
3. **Create OAuth 2.0 Credentials**:
   - Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"
   - Application type: iOS/Android
   - Bundle ID: Your app's bundle identifier
   - **iOS**: Add the URL scheme: `com.googleusercontent.apps.76730819991-pg8rtokoh5urn6d63k3hnc1ksgjt6lo9`
   - **Android**: Add package name and SHA-1 fingerprint

### **2. Microsoft Azure Portal Setup**

1. **Register App**: Go to [Azure Portal](https://portal.azure.com/)
2. **App Registration**: Create new app registration
3. **Configure Redirect URIs**:
   - Add: `com.reminder.reminderplus://auth`
   - Add: `https://login.microsoftonline.com/common/oauth2/nativeclient`
4. **API Permissions**: Add `Mail.Read` permission
5. **Client Secret**: Generate and save client secret
6. **Update Code**: Replace `YOUR_MICROSOFT_CLIENT_ID` with actual client ID

### **3. Bundle Identifier Configuration**

Ensure your app's bundle identifier matches across:
- iOS: `ios/Runner.xcodeproj` → Bundle Identifier
- Android: `android/app/build.gradle` → `applicationId`
- OAuth configurations in both Google and Microsoft portals

---

## 🔍 **Testing OAuth Integration**

### **Google Sign-In Test**

1. **Build and Run**: Deploy app to device/simulator
2. **Navigate**: Go to Email Parsing screen
3. **Connect Gmail**: Tap "Gmail" connection card
4. **Verify**: Should open Google OAuth flow
5. **Check**: After authentication, should show "Connected" status

### **Microsoft OAuth Test**

1. **Build and Run**: Deploy app to device/simulator
2. **Navigate**: Go to Email Parsing screen
3. **Connect Outlook**: Tap "Microsoft Outlook" connection card
4. **Verify**: Should open Microsoft OAuth flow
5. **Check**: After authentication, should show "Connected" status

---

## 🚨 **Troubleshooting**

### **Common Issues**

1. **"URL scheme not supported"**:
   - Verify URL schemes are correctly added to Info.plist
   - Check that bundle identifier matches OAuth configuration
   - Ensure app is properly signed and provisioned

2. **"Invalid client"**:
   - Verify client ID is correct in Google Cloud Console
   - Check that bundle identifier matches exactly
   - Ensure OAuth consent screen is configured

3. **"Redirect URI mismatch"**:
   - Verify redirect URIs match exactly in Azure Portal
   - Check that URL schemes are properly configured
   - Ensure no extra spaces or characters

### **Debug Steps**

1. **Check Console Logs**: Look for OAuth-related error messages
2. **Verify Configuration**: Double-check all URLs and client IDs
3. **Test on Device**: OAuth may not work properly in simulator
4. **Check Network**: Ensure device has internet connectivity

---

## 📋 **Security Considerations**

### **Best Practices**

1. **Client ID Storage**: Store client IDs securely, not in version control
2. **Scope Limitation**: Request only necessary OAuth scopes
3. **Token Management**: Implement proper token refresh logic
4. **Error Handling**: Handle OAuth errors gracefully
5. **User Consent**: Ensure clear user consent for data access

### **Production Checklist**

- [ ] OAuth consent screens configured
- [ ] Production client IDs generated
- [ ] Bundle identifiers finalized
- [ ] Redirect URIs verified
- [ ] Error handling implemented
- [ ] User privacy policy updated

---

## 📞 **Support Resources**

### **Documentation**
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android)
- [Microsoft Graph Authentication](https://docs.microsoft.com/en-us/graph/auth/)

### **Tools**
- [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/)
- [Microsoft Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)

---

*Last Updated: December 2024*  
*Configuration Status: Ready for OAuth Integration*
