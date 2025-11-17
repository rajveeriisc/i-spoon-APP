# 🚀 Environment Setup Guide

## Quick Start

### 1. Generate JWT Secret

Choose one method to generate a secure random secret:

**Method 1: Node.js**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

**Method 2: OpenSSL**
```bash
openssl rand -hex 32
```

**Method 3: Python**
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

**Method 4: Online (Not recommended for production)**
Visit: https://www.random.org/strings/ (64 characters, alphanumeric)

---

### 2. Create `.env` File

Create a file named `.env` in the `ispoon-backend` directory:

```bash
cd ispoon-backend
touch .env
```

---

### 3. Configure Environment Variables

Add the following to your `.env` file:

```env
# ============================================
# REQUIRED - Application will not start without these
# ============================================

# JWT Secret (32+ characters, cryptographically random)
JWT_SECRET=paste_your_generated_secret_here

# Database Connection
DATABASE_URL=postgresql://username:password@localhost:5432/ispoon_db

# ============================================
# OPTIONAL - Has defaults
# ============================================

# Server Configuration
PORT=5000
NODE_ENV=development

# Firebase (if using Firebase Authentication)
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json
```

---

### 4. Example Configuration

**Local Development:**
```env
JWT_SECRET=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
DATABASE_URL=postgresql://postgres:password@localhost:5432/ispoon_dev
PORT=5000
NODE_ENV=development
```

**Production:**
```env
JWT_SECRET=<use_a_different_secret_for_production>
DATABASE_URL=postgresql://prod_user:strong_password@prod-host:5432/ispoon_prod
PORT=5000
NODE_ENV=production
```

---

### 5. Verify Configuration

Run the configuration checker:

```bash
node check-env.js
```

Or start the server (it will fail if configuration is invalid):

```bash
npm run dev
```

If successful, you should see:
```
🚀 iSpoon Backend running on port 5000
```

---

## 🔒 Security Best Practices

### DO ✅
- ✅ Use different secrets for dev/staging/production
- ✅ Generate cryptographically random secrets
- ✅ Keep `.env` files out of version control
- ✅ Use environment variables for all secrets
- ✅ Rotate secrets regularly (every 90 days)
- ✅ Back up your secrets securely
- ✅ Use strong database passwords
- ✅ Enable SSL/TLS for database connections in production

### DON'T ❌
- ❌ Commit `.env` files to Git
- ❌ Use default or example secrets
- ❌ Share secrets in plain text (email, Slack, etc.)
- ❌ Reuse secrets across environments
- ❌ Use short or predictable secrets
- ❌ Hardcode secrets in source code
- ❌ Store secrets in CI/CD logs

---

## 🗃️ Database Setup

### PostgreSQL Installation

**macOS (Homebrew):**
```bash
brew install postgresql
brew services start postgresql
createdb ispoon_dev
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo -u postgres createdb ispoon_dev
```

**Windows:**
Download from: https://www.postgresql.org/download/windows/

### Create Database

```bash
# Connect to PostgreSQL
psql postgres

# Create database
CREATE DATABASE ispoon_dev;

# Create user (optional)
CREATE USER ispoon_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE ispoon_dev TO ispoon_user;

# Exit
\q
```

### Run Migrations

```bash
npm run migrate
```

---

## 🔥 Firebase Setup (Optional)

### 1. Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Follow the setup wizard

### 2. Download Service Account
1. Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save as `serviceAccount.json` in `ispoon-backend/`

### 3. Enable Authentication
1. Authentication → Sign-in method
2. Enable Email/Password
3. Enable Google (optional)

### 4. Configure Environment
```env
FIREBASE_SERVICE_ACCOUNT_PATH=./serviceAccount.json
```

---

## 🧪 Testing Configuration

### Test Authentication
```bash
npm run test:auth
```

### Test Validation
```bash
npm run test:validation
```

### Manual API Test

**Health Check:**
```bash
curl http://localhost:5000/api/health
```

**Signup:**
```bash
curl -X POST http://localhost:5000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#",
    "name": "Test User"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#"
  }'
```

---

## 🐛 Troubleshooting

### Error: "JWT_SECRET environment variable is required"
**Solution:** Set JWT_SECRET in your `.env` file

### Error: "connect ECONNREFUSED"
**Solution:** Ensure PostgreSQL is running and DATABASE_URL is correct

### Error: "Firebase initialization failed"
**Solution:** Check FIREBASE_SERVICE_ACCOUNT_PATH points to valid JSON file

### Port 5000 already in use
**Solution:** Change PORT in `.env` or kill the process using port 5000

```bash
# Find process
lsof -i :5000  # macOS/Linux
netstat -ano | findstr :5000  # Windows

# Kill process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows
```

---

## 📦 Production Deployment

### Environment Variables on Hosting Platforms

**Heroku:**
```bash
heroku config:set JWT_SECRET=your_secret
heroku config:set DATABASE_URL=your_database_url
```

**Vercel/Netlify:**
Add in project settings → Environment Variables

**Docker:**
```yaml
environment:
  - JWT_SECRET=${JWT_SECRET}
  - DATABASE_URL=${DATABASE_URL}
```

**AWS/GCP/Azure:**
Use their respective secret management services:
- AWS Secrets Manager
- GCP Secret Manager  
- Azure Key Vault

---

## 🔄 Secret Rotation

### When to Rotate
- Every 90 days (recommended)
- After a security breach
- When an employee with access leaves
- When secrets may have been exposed

### How to Rotate

1. Generate new secret
2. Update `.env` with new secret
3. Restart application
4. All existing tokens become invalid
5. Users must re-authenticate

**Graceful Rotation (No downtime):**
1. Support multiple secrets temporarily
2. Sign new tokens with new secret
3. Verify tokens with both old and new secrets
4. After expiry period, remove old secret

---

## 📞 Need Help?

- 📖 See [SECURITY_GUIDE.md](./SECURITY_GUIDE.md) for detailed security information
- 📖 See [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) for API reference
- 🐛 Create an issue on GitHub
- 💬 Ask in team chat

---

**Generated:** November 2025  
**Version:** 1.0

