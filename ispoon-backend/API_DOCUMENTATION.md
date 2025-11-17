# 🥄 iSpoon Backend API Documentation

**Base URL (Local):** `http://localhost:5000`

---

## 📋 Table of Contents

- [Authentication](#authentication)
- [User Management](#user-management)
- [Response Format](#response-format)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)

---

## 🔐 Authentication

All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

### 1. **Signup (Email/Password)**
**Endpoint:** `POST /api/auth/signup`

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Test123!@#",
  "name": "John Doe"
}
```

**Response (201):**
```json
{
  "message": "Signup successful",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Validation Rules:**
- Email: Valid format, max 254 chars
- Password: 8+ chars, uppercase, lowercase, number, special character
- Name: Optional, max 100 chars

---

### 2. **Login (Email/Password)**
**Endpoint:** `POST /api/auth/login`

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Test123!@#"
}
```

**Response (200):**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Token Expiry:** 7 days

---

### 3. **Firebase Authentication (Google/Apple/Email)**
**Endpoint:** `POST /api/auth/firebase/verify`

**Request Body:**
```json
{
  "idToken": "<firebase_id_token>"
}
```

**Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "avatar_url": "https://...",
    "firebase_uid": "abc123",
    "auth_provider": "google",
    "email_verified": true
  }
}
```

**Flow:**
1. User authenticates with Firebase (Google/Apple)
2. App gets Firebase ID token
3. Send token to `/api/auth/firebase/verify`
4. Backend verifies with Firebase
5. Backend creates/updates user in PostgreSQL
6. Backend returns JWT token for future requests

---

### 4. **Send Email Verification**
**Endpoint:** `POST /api/auth/firebase/send-verification`

**Request Body:**
```json
{
  "idToken": "<firebase_id_token>"
}
```

**Response (200):**
```json
{
  "message": "Verification email sent"
}
```

---

### 5. **Forgot Password**
**Endpoint:** `POST /api/auth/forgot`

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response (200):**
```json
{
  "message": "If an account exists, a reset email has been sent"
}
```

**Rate Limit:** 5 requests per 15 minutes

**Note:** Always returns success (security best practice - doesn't reveal if email exists)

---

### 6. **Reset Password**
**Endpoint:** `POST /api/auth/reset`

**Request Body:**
```json
{
  "token": "<reset_token_from_email>",
  "password": "NewPassword123!",
  "csrfToken": "<csrf_token>"
}
```

**Response (200):**
```json
{
  "message": "Password updated"
}
```

**Rate Limit:** 5 requests per 15 minutes

---

### 7. **Logout**
**Endpoint:** `POST /api/auth/logout`

**Response (200):**
```json
{
  "message": "Logged out"
}
```

**Note:** Client must delete the stored JWT token

---

## 👤 User Management

### 1. **Get Current User Profile**
**Endpoint:** `GET /api/users/me`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (200):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "phone": "1234567890",
    "location": "New York",
    "bio": "Smart spoon user",
    "diet_type": "vegetarian",
    "activity_level": "moderate",
    "allergies": ["peanuts", "shellfish"],
    "daily_goal": 2000,
    "notifications_enabled": true,
    "emergency_contact": "Jane Doe - 9876543210",
    "avatar_url": "/uploads/avatars/u_123456.jpg",
    "auth_provider": "firebase",
    "email_verified": true,
    "created_at": "2025-01-01T00:00:00.000Z",
    "updated_at": "2025-01-07T12:00:00.000Z"
  }
}
```

---

### 2. **Update User Profile**
**Endpoint:** `PUT /api/users/me`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body (all fields optional):**
```json
{
  "name": "John Smith",
  "phone": "1234567890",
  "location": "San Francisco",
  "bio": "Health enthusiast",
  "diet_type": "vegan",
  "activity_level": "high",
  "allergies": ["gluten"],
  "daily_goal": 2500,
  "notifications_enabled": false,
  "emergency_contact": "Jane - 9876543210"
}
```

**Response (200):**
```json
{
  "message": "Profile updated",
  "user": {
    // updated user object
  }
}
```

**Field Limits:**
- name: max 100 chars
- phone: max 20 chars
- location: max 200 chars
- bio: max 500 chars
- emergency_contact: max 100 chars
- allergies: max 20 items
- daily_goal: max 10,000

---

### 3. **Upload Avatar**
**Endpoint:** `POST /api/users/me/avatar`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: multipart/form-data
```

**Request Body (FormData):**
```
avatar: <image_file>
```

**Allowed Formats:** PNG, JPG, JPEG, WebP  
**Max Size:** 2MB

**Response (200):**
```json
{
  "message": "Avatar updated",
  "user": {
    "avatar_url": "/uploads/avatars/u_1699123456_x9y8z7.jpg"
    // ... rest of user object
  }
}
```

---

### 4. **Remove Avatar**
**Endpoint:** `DELETE /api/users/me/avatar`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (200):**
```json
{
  "message": "Avatar removed",
  "user": {
    "avatar_url": null
    // ... rest of user object
  }
}
```

---

## 📄 Response Format

### Success Response
```json
{
  "message": "Operation successful",
  "data": { /* response data */ }
}
```

### Error Response
```json
{
  "message": "Error description",
  "errors": {
    "field_name": "Specific error message"
  }
}
```

---

## ⚠️ Error Handling

### HTTP Status Codes

| Code | Meaning | When |
|------|---------|------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid input/validation error |
| 401 | Unauthorized | Missing or invalid token |
| 403 | Forbidden | Valid token but insufficient permissions |
| 404 | Not Found | Resource doesn't exist |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Database or service down |

### Common Error Messages

**Authentication Errors:**
```json
{
  "message": "Invalid credentials"
}
```

**Validation Errors:**
```json
{
  "message": "Validation failed",
  "errors": {
    "email": "Email must be valid",
    "password": "Password must be 8+ chars with upper, lower, number, special"
  }
}
```

**Rate Limit Error:**
```json
{
  "message": "Too many requests, please try again later."
}
```

---

## 🚦 Rate Limiting

### General API
- **Limit:** 100 requests per 15 minutes
- **Applies to:** All API endpoints (except auth)

### Authentication Endpoints
- **Limit:** 5 requests per 15 minutes
- **Applies to:** Login, signup, firebase/verify

### Password Reset
- **Limit:** 5 requests per 15 minutes
- **Applies to:** Forgot password, reset password

### Headers (in response)
```
RateLimit-Limit: 100
RateLimit-Remaining: 95
RateLimit-Reset: 1699123456
```

---

## 🔧 Health Check

### Check API Status
**Endpoint:** `GET /api/health`

**Response (200):**
```json
{
  "status": "ok",
  "timestamp": "2025-01-07T12:00:00.000Z",
  "uptime": 12345.67,
  "services": {
    "database": "ok",
    "firebase": "ok"
  }
}
```

**Response (503) - Service Degraded:**
```json
{
  "status": "degraded",
  "timestamp": "2025-01-07T12:00:00.000Z",
  "uptime": 12345.67,
  "services": {
    "database": "error",
    "firebase": "ok"
  }
}
```

---

## 📱 Frontend Integration Examples

### Flutter (Dart) Example

```dart
// Login
final response = await http.post(
  Uri.parse('$baseUrl/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'email': email,
    'password': password,
  }),
);

// Get user profile
final response = await http.get(
  Uri.parse('$baseUrl/api/users/me'),
  headers: {
    'Authorization': 'Bearer $token',
  },
);

// Upload avatar
final request = http.MultipartRequest(
  'POST',
  Uri.parse('$baseUrl/api/users/me/avatar'),
);
request.headers['Authorization'] = 'Bearer $token';
request.files.add(
  await http.MultipartFile.fromPath('avatar', imagePath),
);
final response = await request.send();
```

---

## 🔒 Security Best Practices

1. **Always use HTTPS** in production
2. **Store JWT tokens securely** (Flutter Secure Storage)
3. **Never log sensitive data** (passwords, tokens)
4. **Implement token refresh** before 7-day expiry
5. **Validate input** on client side before sending
6. **Handle rate limits** gracefully with retry logic
7. **Clear tokens** on logout or authentication errors

---

## 🛠️ Development Tips

### Local Testing
```bash
# Start server
cd ispoon-backend
npm run dev

# Test health check
curl http://localhost:5000/api/health

# Test login
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#"}'
```

### Environment Variables
```env
PORT=5000
DATABASE_URL=postgresql://user:password@localhost:5432/ispoon
JWT_SECRET=your-super-secret-key-minimum-32-chars
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY="your-private-key"
```

---

## 📞 Support

For questions or issues:
- Check server logs: `npm run dev`
- Verify database connection: `npm run db:health`
- Test auth endpoints: `npm run test:auth`

---

**Last Updated:** January 7, 2025  
**Version:** 1.0.0  
**API Base URL:** `/api`

