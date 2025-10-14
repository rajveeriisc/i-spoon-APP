# Firebase Setup Instructions

Firebase has been integrated into the app. Follow these steps to configure it with your actual Firebase project:

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select existing project `i-spoon-auth`
3. Enable Google Analytics (optional)

## Step 2: Register Your Apps

### Android App
1. In Firebase Console, click "Add app" → Android
2. Package name: `com.example.smartspoon` (or check `android/app/build.gradle.kts`)
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

### iOS App
1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.example.smartspoon` (or check `ios/Runner.xcodeproj`)
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### Web App
1. In Firebase Console, click "Add app" → Web
2. Register app and copy the config

## Step 3: Update Firebase Options

Replace the placeholder values in `lib/firebase_options.dart` with your actual credentials from Firebase Console:

```dart
// Get these from: Firebase Console → Project Settings → Your apps
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'i-spoon-auth',
  storageBucket: 'i-spoon-auth.appspot.com',
);
```

## Step 4: Enable Authentication

1. In Firebase Console → Authentication → Get Started
2. Enable "Email/Password" sign-in method
3. (Optional) Enable other providers (Google, Apple, etc.)

## Step 5: Enable Firestore

1. In Firebase Console → Firestore Database → Create database
2. Start in **test mode** (for development)
3. Choose a location (e.g., us-central)

## Step 6: Test

Run the app:
```bash
flutter run
```

## Current Status

✅ Firebase packages installed
✅ Firebase initialized in `main.dart`
✅ Placeholder config created
⚠️ **ACTION REQUIRED**: Replace placeholder credentials with real ones

## Files Modified

- `pubspec.yaml` - Added firebase_core, firebase_auth, cloud_firestore
- `lib/main.dart` - Added Firebase initialization
- `lib/firebase_options.dart` - Created (needs real credentials)

## Next Steps

After setting up Firebase:
1. Update `lib/services/auth_service.dart` to use Firebase Auth instead of custom backend
2. Migrate user data to Firestore
3. Set up Firestore security rules

