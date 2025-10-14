# iSpoon Backend

A secure Node.js/Express backend for the SmartSpoon mobile app, using Firebase Authentication and Neon PostgreSQL.

## Features

- **Firebase-first Authentication**: Email/password and Google sign-in with email verification
- **Secure API**: JWT-based authorization with rate limiting and input sanitization
- **Data Retention**: Automated cleanup of expired tokens and inactive data
- **Production Ready**: Security headers, CORS, and environment-based configuration

## Quick Start

```bash
# Install dependencies
npm install

# Set up environment variables (see below)
cp .env.example .env

# Run database migrations
npm run seed
node src/scripts/add_social_auth_fields.js

# Start development server
npm run dev
```

## Environment Variables

Create `.env` in the `ispoon-backend/` directory:

```env
NODE_ENV=development
PORT=5000
JWT_SECRET=your-secure-jwt-secret-min-32-chars

# Neon PostgreSQL
DATABASE_URL=postgres://user:password@host:port/db?sslmode=require

# Firebase Admin (preferred: use GOOGLE_APPLICATION_CREDENTIALS)
GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
# OR manual config:
# FIREBASE_PROJECT_ID=your-project-id
# FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project-id.iam.gserviceaccount.com
# FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

## Authentication Flow

1. **Client Authentication**: Mobile/web clients authenticate with Firebase Auth (email/password or Google)
2. **Token Exchange**: Client sends Firebase ID token to `POST /api/auth/firebase/verify`
3. **Backend Verification**: Server verifies token using Firebase Admin SDK
4. **User Upsert**: Backend creates/updates user in NeonDB with enriched profile data
5. **JWT Response**: Backend returns its own JWT for subsequent API calls
6. **Protected Routes**: All API calls use `Authorization: Bearer <jwt>` header

### Email Verification
- Email/password signups require email verification before backend access
- Firebase sends verification email automatically on signup
- Unverified accounts return 403 until email is verified

## Security Features

### Rate Limiting
- **Auth endpoints**: 5 requests per 15 minutes per IP
- **General API**: 100 requests per 15 minutes per IP
- **Password reset**: 3 requests per hour per IP

### Input Validation & Sanitization
- All user inputs are validated and sanitized before processing
- SQL injection prevention through parameterized queries
- XSS protection via Helmet security headers
- Input length limits enforced

### CORS & Security Headers
- Configurable allowed origins (restrictive in production)
- Helmet security headers with COOP/COEP disabled for GIS popups
- Content Security Policy for XSS protection

### Data Security
- Passwords hashed with bcrypt (salt rounds: 10)
- JWT tokens with configurable expiration (7 days default)
- Secure random token generation for password resets
- Automated cleanup of expired reset tokens (24h retention)

## API Endpoints

### Authentication
- `POST /api/auth/firebase/verify` - Exchange Firebase ID token for backend JWT
- `POST /api/auth/forgot` - Request password reset email (legacy)
- `POST /api/auth/reset` - Reset password with token (legacy)

### User Management
- `GET /api/users/me` - Get current user profile
- `PUT /api/users/me` - Update user profile
- `POST /api/users/me/avatar` - Upload user avatar
- `DELETE /api/users/me/avatar` - Remove user avatar

## Database Schema

### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password TEXT, -- Nullable for Firebase-only users
  name TEXT,
  phone TEXT,
  location TEXT,
  bio TEXT,
  diet_type TEXT,
  activity_level TEXT,
  allergies TEXT[],
  daily_goal INTEGER,
  notifications_enabled BOOLEAN,
  emergency_contact TEXT,
  avatar_url TEXT,
  firebase_uid VARCHAR(255) UNIQUE,
  auth_provider VARCHAR(50) DEFAULT 'email',
  email_verified BOOLEAN DEFAULT false,
  reset_token TEXT,
  reset_token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Maintenance Scripts

```bash
# Initial setup
npm run seed                    # Create users table and sample data
node src/scripts/add_social_auth_fields.js  # Add Firebase columns

# Data cleanup
node src/scripts/cleanup.js     # Remove expired tokens and old data

# Testing
npm run test:auth              # Test authentication endpoints
npm run test:validation        # Test input validation
```

## Deployment

### Production Checklist
- [ ] Set `NODE_ENV=production` in environment
- [ ] Update `SECURITY_CONFIG.ALLOWED_ORIGINS` with your domains
- [ ] Configure proper Firebase authorized domains
- [ ] Set up SSL certificates for HTTPS
- [ ] Configure database connection pooling limits
- [ ] Set up monitoring and logging
- [ ] Regular security audits and dependency updates

### Docker Deployment
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
```

## Troubleshooting

### Common Issues

**Firebase Admin fails to initialize**
- Ensure `GOOGLE_APPLICATION_CREDENTIALS` points to valid service account JSON
- Or set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` in `.env`
- Check Firebase Console → Project Settings → Service Accounts

**Database connection fails**
- Verify `DATABASE_URL` format and credentials
- Ensure Neon database allows connections from your IP

**Email verification not working**
- Check Firebase Auth settings for authorized domains
- Verify SMTP settings if using custom email provider

**CORS errors in browser**
- Update `SECURITY_CONFIG.ALLOWED_ORIGINS` for your domains
- Check if preflight requests are handled correctly

### Logs and Debugging
- Set `NODE_ENV=development` for detailed error messages
- Check console logs for security events and errors
- Use `npm run test:auth` to verify authentication flow



