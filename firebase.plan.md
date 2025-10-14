### Firebase Auth as IdP, NeonDB for profiles

#### Decision

- Use Firebase for signup/signin only (no passwords in Neon).
- Keep a minimal `users` row in Neon (email, name, avatar_url, firebase_uid) for profiles/joins.
- Continue issuing a backend JWT after verifying the Firebase ID token to work with existing `protect` middleware.

#### Backend

- Keep `POST /api/auth/firebase/verify` to:
  - Verify Firebase ID token via Admin SDK.
  - Upsert user in Neon by `firebase_uid` (or by email fallback).
  - Return backend JWT with `id` and `email`.
- Deprecate native `POST /api/auth/signup`, `POST /api/auth/login`, and password reset endpoints (kept for backward compatibility; not used by mobile app).
- Ensure env setup for Firebase Admin in `ispoon-backend/.env` (project id, client email, private key with \n escapes).
- No writes to Firebase databases (Firestore/RTDB) — Firebase is auth-only.

#### Middleware and Controllers

- Keep `authMiddleware.protect` as-is (uses backend JWT). No changes needed in `userController` because JWT still contains `id`.
- Leave the Neon upsert logic in `firebaseAuthController.verifyFirebaseToken` to ensure a user row exists for profile features.

#### Frontend (Flutter)

- Use Firebase Auth SDK for signup/signin (email/pass, Google, etc.).
- After signin, get `idToken` and call `POST /api/auth/firebase/verify` to exchange for backend JWT.
- Store backend JWT and send as `Authorization: Bearer <jwt>` for all API calls.
- Do not call native `/signup` or `/login` endpoints.

#### Operational

- `.env` formatting for `FIREBASE_PRIVATE_KEY` must be quoted, single line with literal `\n`.
- `serviceAccount.json` present for MCP if needed; backend uses env vars.
- MCP servers optional; do not block auth flow.

#### Minimal Data Model

- Use current `users` table with `firebase_uid` column (migrations added). Password field unused.

### Status

- Backend verify endpoint and Neon upsert: DONE
- Native auth endpoints deprecated in docs/comments: DONE
- Flutter wired to Firebase + backend token exchange: DONE
- READMEs updated: DONE
- Firebase Admin env vars: PENDING (ensure correct `.env` values and restart)
- E2E test (Firebase sign-in → verify → protected API): PENDING
