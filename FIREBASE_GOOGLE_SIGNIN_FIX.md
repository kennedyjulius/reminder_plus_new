# 🔧 Fix Google Sign-In Configuration

## Problem
Google Sign-in is failing because OAuth client IDs are not configured in Firebase Console.

## Root Cause
The `google-services.json` file shows an empty `oauth_client` array, which means:
- OAuth client IDs haven't been added to Firebase Console
- SHA-1 certificate fingerprints may not be registered

## Solution: Configure Firebase Console

### Step 1: Add SHA-1 Fingerprints to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **voicereminder-30acc**
3. Go to **Project Settings** (gear icon)
4. Scroll down to **Your apps** section
5. Click on your Android app: **com.reminder.reminderplus**
6. Click **Add fingerprint** and add these SHA-1 fingerprints:

#### Release Keystore (for production builds):
```
31:9F:62:2D:4C:17:B8:CE:02:D7:9B:AE:A3:8D:E7:B6:48:EF:C5:D6
```

#### Debug Keystore (for testing):
```
8A:3B:E6:DE:EB:88:49:14:36:36:47:46:4B:2A:A4:32:73:FD:CA:47
```

### Step 2: Enable Google Sign-In Method

1. In Firebase Console, go to **Authentication** → **Sign-in method**
2. Click on **Google** provider
3. Enable it if not already enabled
4. Make sure **Support email** is set
5. Click **Save**

### Step 3: Configure OAuth Consent Screen (if needed)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **voicereminder-30acc** (or your Firebase project)
3. Go to **APIs & Services** → **OAuth consent screen**
4. Configure the consent screen:
   - User Type: **External** (or Internal if using Google Workspace)
   - App name: **Remind Plus**
   - Support email: Your email
   - Developer contact: Your email
5. Add scopes:
   - `email`
   - `profile`
   - `openid`
6. Add test users if app is in testing mode
7. Click **Save and Continue**

### Step 4: Create OAuth 2.0 Client IDs

1. In Google Cloud Console, go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth 2.0 Client ID**
3. Create **Web client** (for Firebase Auth):
   - Application type: **Web application**
   - Name: **Remind Plus Web Client**
   - Authorized redirect URIs: Leave empty (Firebase handles this)
   - Click **Create**
   - **Copy the Client ID** (you'll need this)

4. The Android client should be created automatically by Firebase, but verify:
   - Look for **Android client** with package name: `com.reminder.reminderplus`
   - If missing, create it manually:
     - Application type: **Android**
     - Package name: `com.reminder.reminderplus`
     - SHA-1: `31:9F:62:2D:4C:17:B8:CE:02:D7:9B:AE:A3:8D:E7:B6:48:EF:C5:D6`

### Step 5: Link Web Client ID to Firebase

1. Go back to Firebase Console
2. **Authentication** → **Sign-in method** → **Google**
3. Under **Web SDK configuration**, paste the **Web client ID** from Step 4
4. Click **Save**

### Step 6: Download Updated google-services.json

1. In Firebase Console, go to **Project Settings**
2. Scroll to **Your apps** → Android app
3. Click **Download google-services.json**
4. Replace `android/app/google-services.json` with the new file
5. The new file should have `oauth_client` entries (not empty array)

### Step 7: Rebuild the App

```bash
cd /home/kennedyjulius/Downloads/reminder_plus-main
flutter clean
flutter pub get
flutter build apk --release
# or
flutter build appbundle --release
```

## Verification

After completing the above steps:

1. The `google-services.json` file should have entries in the `oauth_client` array
2. Run the app and try Google Sign-in
3. Check console logs for detailed error messages if it still fails

## Common Issues

### Error: "ApiException: 10" (DEVELOPER_ERROR)
- **Cause**: SHA-1 fingerprint not registered or OAuth client ID mismatch
- **Fix**: Ensure SHA-1 fingerprints are added in Firebase Console (Step 1)

### Error: "Missing access token or ID token"
- **Cause**: OAuth client IDs not configured
- **Fix**: Complete Steps 2-6 above

### Error: "Invalid credential"
- **Cause**: Web client ID not linked to Firebase
- **Fix**: Complete Step 5 above

## Current Configuration Status

- ✅ Package name: `com.reminder.reminderplus`
- ✅ Release SHA-1: `31:9F:62:2D:4C:17:B8:CE:02:D7:9B:AE:A3:8D:E7:B6:48:EF:C5:D6`
- ✅ Debug SHA-1: `8A:3B:E6:DE:EB:88:49:14:36:36:47:46:4B:2A:A4:32:73:FD:CA:47`
- ❌ OAuth client IDs: **Not configured** (empty array in google-services.json)
- ❌ Web client ID: **Not linked to Firebase**

## Next Steps

1. Complete all steps above
2. Test Google Sign-in with a debug build first
3. Once working, test with release build
4. If issues persist, check console logs for specific error codes


