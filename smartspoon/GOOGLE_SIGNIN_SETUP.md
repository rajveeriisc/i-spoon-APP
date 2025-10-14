# Google Sign-In Setup

Google Sign-In has been integrated. Follow these steps to complete the setup:

## ✅ Already Done
- ✅ `google_sign_in` package added
- ✅ `FirebaseAuthService` created with Google Sign-In logic
- ✅ Login screen updated with working Google button
- ✅ Firebase Authentication enabled

## 🔴 Required: Enable Google Sign-In in Firebase

### Step 1: Enable Google Authentication
1. Go to [Firebase Console](https://console.firebase.google.com/project/i-spoon-auth/authentication/providers)
2. Click **Authentication** → **Sign-in method**
3. Click **Google** → **Enable**
4. Set **Project support email** (your email)
5. Click **Save**

### Step 2: Get SHA-1 Certificate (Android)

For Google Sign-In to work on Android, you need to add your SHA-1 certificate:

#### Debug SHA-1 (for development):
```bash
cd android
./gradlew signingReport
```

Or on Windows:
```bash
cd android
gradlew.bat signingReport
```

Look for the **SHA-1** under `Variant: debug` and copy it.

#### Alternative method (using keytool):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Step 3: Add SHA-1 to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/project/i-spoon-auth/settings/general)
2. Scroll to **Your apps** → Select your Android app
3. Click **Add fingerprint**
4. Paste your SHA-1 certificate
5. Click **Save**
6. Download the updated `google-services.json`
7. Replace `android/app/google-services.json` with the new file

### Step 4: Test

Run the app:
```bash
flutter run
```

Click the Google icon on the login screen. It should:
1. Open Google account picker
2. Sign you in
3. Navigate to home page

## Troubleshooting

### Error: "PlatformException(sign_in_failed)"
- **Cause**: SHA-1 not added to Firebase
- **Fix**: Complete Step 2 & 3 above

### Error: "Google Sign-In cancelled"
- **Cause**: User cancelled the sign-in flow
- **Fix**: This is normal, try again

### Error: "API not enabled"
- **Cause**: Google Sign-In API not enabled
- **Fix**: Go to [Google Cloud Console](https://console.cloud.google.com/apis/library/identitytoolkit.googleapis.com?project=i-spoon-auth) and enable "Identity Toolkit API"

## Current OAuth Client

From your `google-services.json`:
```
Client ID: 129116938699-arcgegjkutao02cc5j87elu9nq7ejg2b.apps.googleusercontent.com
```

This is automatically configured when you enable Google Sign-In in Firebase.

## Files Modified

- `pubspec.yaml` - Added `google_sign_in: ^6.2.1`
- `lib/services/firebase_auth_service.dart` - Created with Google Sign-In
- `lib/pages/login_screen.dart` - Added `_signInWithGoogle()` method

## Next Steps

1. Enable Google Sign-In in Firebase Console (Step 1)
2. Add SHA-1 certificate (Steps 2 & 3)
3. Test the Google Sign-In button
4. (Optional) Add the same to Sign-Up screen

