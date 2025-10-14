# SmartSpoon – Auth Overview

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## Authentication

- Uses Firebase Auth (email/password and Google) for signup/signin.
- After Firebase signin, the app calls the backend `POST /api/auth/firebase/verify` with the Firebase ID token.
- Backend returns a JWT used for all subsequent API calls.

Environment:
- Backend base URL defaults to `http://10.0.2.2:5000` on Android emulator and `http://localhost:5000` otherwise.

Troubleshooting:
- Ensure backend `.env` is configured for Firebase Admin.
- Run backend migration for Firebase fields if first-time setup: `node ispoon-backend/src/scripts/add_social_auth_fields.js`.
