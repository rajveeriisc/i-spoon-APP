# 🔐 iSpoon Backend - Security Guide

## Overview
This document outlines security best practices and configuration for the iSpoon backend.

---

## 🚨 Critical Security Requirements

### 1. JWT Secret Configuration

**Status:** ✅ **FIXED** - Now requires JWT_SECRET to be set

The JWT secret is used to sign authentication tokens. It MUST be:
- At least 32 characters long
- Cryptographically random
- Different for each environment (dev, staging, production)
- Rotated regularly (every 90 days recommended)

**Generate a secure JWT secret:**

```bash
# Using Node.js
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# Using OpenSSL
openssl rand -hex 32

# Using Python
python3 -c "import secrets; print(secrets.token_hex(32))"
```

**Configuration:**

Create a `.env` file in the `ispoon-backend` directory:

```env
JWT_SECRET=your_generated_secret_key_here_minimum_32_characters
DATABASE_URL=postgresql://username:password@localhost:5432/ispoon_db
PORT=5000
NODE_ENV=development
```

⚠️ **NEVER:**
- Commit `.env` files to version control
- Use default or example secrets in production
- Share secrets in plain text
- Hardcode secrets in source code

---

## 🔒 JWT Token Security

### Current Implementation (Enhanced)

**Token Structure:**
```json
{
  "id": 123,
  "email": "user@example.com",
  "type": "access",
  "firebase_uid": "optional_firebase_uid",
  "iss": "i-spoon-backend",
  "aud": "i-spoon-mobile",
  "sub": "123",
  "iat": 1699900000,
  "exp": 1700504800
}
```

**Security Features:**
- ✅ Issuer verification (`iss`)
- ✅ Audience verification (`aud`)
- ✅ Subject tracking (`sub`)
- ✅ Algorithm restriction (HS256 only)
- ✅ Token expiry (7 days)
- ✅ Secure storage (Flutter Secure Storage)
- ✅ Automatic expiry validation

### Token Lifecycle

```
┌─────────────┐
│   Login     │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  Generate JWT       │
│  - Sign with secret │
│  - Set expiry (7d)  │
│  - Add claims       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Store Securely     │
│  (Secure Storage)   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Every API Call     │
│  - Validate token   │
│  - Check expiry     │
│  - Verify claims    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Auto-refresh       │
│  (1 day before exp) │
└─────────────────────┘
```

---

## 🛡️ Authentication Flow

### Standard Login (Email/Password)

```
Client                    Backend                    Database
  │                         │                           │
  ├─── POST /auth/login ──>│                           │
  │    {email, password}    │                           │
  │                         ├─── Query user ─────────>│
  │                         │<─── User data ───────────┤
  │                         │                           │
  │                         ├─ Verify password         │
  │                         │  (bcrypt.compare)        │
  │                         │                           │
  │                         ├─ Generate JWT            │
  │                         │  (jwt.sign)              │
  │                         │                           │
  │<─── {token, user} ──────┤                           │
  │                         │                           │
  ├─ Store token           │                           │
  │  (Secure Storage)       │                           │
```

### Firebase Authentication Flow

```
Client                    Backend                    Firebase
  │                         │                           │
  ├─ Firebase login ──────>│                           │
  │                         │                           │
  │<─── ID Token ───────────┤                           │
  │                         │                           │
  ├─ POST /auth/firebase/ ->│                           │
  │    verify {idToken}     │                           │
  │                         ├─ Verify ID token ───────>│
  │                         │<─ User claims ────────────┤
  │                         │                           │
  │                         ├─ Upsert user in DB       │
  │                         │                           │
  │                         ├─ Generate JWT            │
  │                         │                           │
  │<─── {token, user} ──────┤                           │
```

---

## 🔐 Password Security

### Current Implementation

**Hashing:** bcrypt with 10 salt rounds

**Requirements (enforced):**
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character

**Code:**
```javascript
// Hashing
const hashed = await bcrypt.hash(password, 10);

// Verification
const match = await bcrypt.compare(password, user.password);
```

### Password Reset Flow

```
1. User requests reset → POST /auth/forgot
2. Backend generates secure token (crypto.randomBytes)
3. Token stored in DB with expiry (1 hour)
4. Email sent with reset link
5. User clicks link → Validates CSRF token
6. User submits new password → POST /auth/reset
7. Backend validates token & CSRF
8. Password updated with bcrypt
9. Token invalidated
```

**Security Features:**
- ✅ Secure token generation
- ✅ Time-limited tokens (1 hour)
- ✅ CSRF protection
- ✅ Password strength validation
- ✅ Generic success/error messages (no user enumeration)

---

## 🚦 Rate Limiting

### Current Configuration

**Authentication Endpoints:** `/api/auth/*`
- **Window:** 15 minutes
- **Max Requests:** 5
- **Purpose:** Prevent brute force attacks

**General Endpoints:** All other routes
- **Window:** 15 minutes
- **Max Requests:** 100
- **Purpose:** Prevent DoS attacks

**Password Reset:** `/api/auth/forgot`, `/api/auth/reset`
- **Window:** 1 hour
- **Max Requests:** 3
- **Purpose:** Prevent email bombing

### Customization

Edit `src/config/security.js`:

```javascript
export const SECURITY_CONFIG = {
  RATE_LIMITS: {
    AUTH: { windowMs: 15 * 60 * 1000, max: 5 },
    GENERAL: { windowMs: 15 * 60 * 1000, max: 100 },
    RESET: { windowMs: 60 * 60 * 1000, max: 3 },
  },
  // ...
};
```

---

## 🌐 CORS Configuration

### Development
```javascript
origin: true, // Allow all origins
credentials: true
```

### Production (RECOMMENDED)
```javascript
origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
credentials: true,
methods: ['GET', 'POST', 'PUT', 'DELETE'],
allowedHeaders: ['Content-Type', 'Authorization']
```

**Configure in:** `src/app.js`

---

## 🛡️ Security Headers (Helmet)

### Current Configuration

```javascript
helmet({
  crossOriginOpenerPolicy: false, // For Google Sign-In
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://*.googleapis.com", "https://*.firebaseio.com"],
    },
  },
})
```

**Features:**
- XSS Protection
- Content Security Policy
- X-Frame-Options (clickjacking prevention)
- Strict-Transport-Security (HTTPS enforcement)
- X-Content-Type-Options (MIME sniffing prevention)

---

## 📱 Client-Side Security (Flutter)

### Secure Token Storage

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

static final FlutterSecureStorage _storage = const FlutterSecureStorage();

// Store token
await _storage.write(key: 'auth_token', value: token);

// Retrieve token
final token = await _storage.read(key: 'auth_token');

// Delete token
await _storage.delete(key: 'auth_token');
```

**Features:**
- ✅ Encrypted storage (iOS Keychain, Android Keystore)
- ✅ Memory fallback for unsupported platforms
- ✅ Automatic token validation
- ✅ Token expiry checking
- ✅ Scheduled refresh

### Token Validation

```dart
// Check if token is valid
final isValid = await AuthService.isTokenValid();

// Get token only if valid
final token = await AuthService.getValidToken();
```

---

## 🔍 Common Attack Vectors & Mitigations

| Attack | Mitigation | Status |
|--------|-----------|---------|
| **Brute Force** | Rate limiting (5 attempts/15min) | ✅ Implemented |
| **JWT Secret Exposure** | Environment variables only | ✅ Implemented |
| **Token Theft** | HTTPS only, secure storage | ⚠️ Enable HTTPS |
| **XSS** | Helmet, CSP headers | ✅ Implemented |
| **SQL Injection** | Parameterized queries | ✅ Implemented |
| **CSRF** | Token validation for state-changing ops | ✅ Implemented |
| **Replay Attacks** | Token expiry, timestamp validation | ✅ Implemented |
| **Algorithm Confusion** | Explicit algorithm restriction | ✅ Implemented |
| **Token Expiry** | 7-day expiry, refresh mechanism | ✅ Implemented |
| **Password Storage** | bcrypt hashing (10 rounds) | ✅ Implemented |
| **DoS** | Rate limiting (100 req/15min) | ✅ Implemented |
| **Information Disclosure** | Generic error messages | ✅ Implemented |
| **Session Fixation** | Stateless JWT, no session IDs | ✅ Implemented |

---

## 📋 Security Checklist

### Development ✅
- [x] JWT secret required (no default)
- [x] Password hashing (bcrypt)
- [x] Rate limiting configured
- [x] Input validation
- [x] Secure token storage
- [x] Token expiry validation
- [x] Algorithm restriction
- [x] Issuer/Audience verification

### Pre-Production ⚠️
- [ ] Generate production JWT secret (32+ chars)
- [ ] Configure CORS for specific origins
- [ ] Enable HTTPS/TLS
- [ ] Set NODE_ENV=production
- [ ] Review rate limits for production scale
- [ ] Configure Firebase production project
- [ ] Set up database backups
- [ ] Configure logging/monitoring
- [ ] Security audit/penetration testing
- [ ] Review error messages (no information leakage)

### Production 🚀
- [ ] Rotate JWT secrets (every 90 days)
- [ ] Monitor failed auth attempts
- [ ] Set up alerting for security events
- [ ] Regular security updates
- [ ] GDPR/Privacy compliance
- [ ] Backup and disaster recovery
- [ ] API documentation (with auth examples)
- [ ] Security headers verification
- [ ] SSL/TLS certificate monitoring
- [ ] Database security hardening

---

## 🔧 Testing Authentication

### Manual Testing

```bash
# 1. Signup
curl -X POST http://localhost:5000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#","name":"Test User"}'

# 2. Login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#"}'

# 3. Get user profile (with token)
curl -X GET http://localhost:5000/api/users/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# 4. Test rate limiting (run multiple times quickly)
for i in {1..10}; do
  curl -X POST http://localhost:5000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"wrong"}';
done
```

### Automated Testing

```bash
cd ispoon-backend
npm run test:auth
npm run test:validation
```

---

## 📚 Additional Resources

### JWT Best Practices
- [RFC 7519 - JSON Web Tokens](https://tools.ietf.org/html/rfc7519)
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)

### Security Standards
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP API Security](https://owasp.org/www-project-api-security/)
- [CWE Top 25](https://cwe.mitre.org/top25/)

### Flutter Security
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)

---

## 🆘 Security Incident Response

If you discover a security vulnerability:

1. **DO NOT** disclose it publicly
2. Document the vulnerability details
3. Assess the impact and severity
4. Implement a fix
5. Test the fix thoroughly
6. Deploy to production ASAP
7. Notify affected users if necessary
8. Post-mortem and preventive measures

---

## 📞 Contact

For security concerns or questions:
- Create a private security issue
- Email: security@yourdomain.com (set up a dedicated security email)

---

**Last Updated:** November 2025  
**Version:** 1.0  
**Status:** Production Ready ✅

