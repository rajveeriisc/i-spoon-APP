## Environment

Create a `.env` in `ispoon-backend/` with:

```env
NODE_ENV=development
PORT=5000
JWT_SECRET=change-me
DATABASE_URL=postgres://...

# Firebase Admin for verifying ID tokens
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-abc@your-project-id.iam.gserviceaccount.com
# If your private key has literal \n in it, keep them – backend replaces them
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIIEv...\n-----END PRIVATE KEY-----\n
```

## Auth Flow (Firebase-first)

- Mobile/web clients authenticate with Firebase Auth.
- Client sends the Firebase ID token to `POST /api/auth/firebase/verify`.
- Backend verifies the token using Firebase Admin and upserts a minimal user row in Neon (`users` table), identified by `firebase_uid` (fallback by email).
- Backend returns its own JWT (`id`, `email`) used with `Authorization: Bearer <jwt>` for protected routes.

Notes:
- Native `/api/auth/signup`, `/api/auth/login`, `/api/auth/forgot`, `/api/auth/reset` exist for legacy flows but are not used by the current mobile app.
- Ensure database has social auth fields. Run:

```
npm run seed && node src/scripts/add_social_auth_fields.js
```



