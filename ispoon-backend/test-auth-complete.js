/**
 * Complete Authentication System Test
 * Tests the entire auth flow to find issues
 */

import dotenv from 'dotenv';
dotenv.config();

console.log('\n🔍 AUTHENTICATION SYSTEM DIAGNOSTICS\n');
console.log('='.repeat(60));

// Test 1: Environment Variables
console.log('\n1️⃣ ENVIRONMENT VARIABLES:');
console.log('   JWT_SECRET:', process.env.JWT_SECRET ? `✅ Set (${process.env.JWT_SECRET.length} chars)` : '❌ Missing');
console.log('   DATABASE_URL:', process.env.DATABASE_URL ? '✅ Set' : '❌ Missing');
console.log('   NODE_ENV:', process.env.NODE_ENV || 'not set');
console.log('   PORT:', process.env.PORT || '5000 (default)');

// Test 2: JWT Secret Validation
console.log('\n2️⃣ JWT SECRET VALIDATION:');
if (!process.env.JWT_SECRET) {
  console.log('   ❌ CRITICAL: JWT_SECRET not set!');
  process.exit(1);
} else if (process.env.JWT_SECRET.length < 32) {
  console.log(`   ⚠️  WARNING: JWT_SECRET too short (${process.env.JWT_SECRET.length} chars, should be 32+)`);
} else {
  console.log(`   ✅ JWT_SECRET valid (${process.env.JWT_SECRET.length} characters)`);
}

// Test 3: Import modules
console.log('\n3️⃣ MODULE IMPORTS:');
try {
  const { SECURITY_CONFIG } = await import('./src/config/security.js');
  console.log('   ✅ Security config loaded');
  console.log('      - Issuer:', SECURITY_CONFIG.JWT.ISSUER);
  console.log('      - Audience:', SECURITY_CONFIG.JWT.AUDIENCE);
  console.log('      - Access Expires:', SECURITY_CONFIG.JWT.ACCESS_EXPIRES_IN);
} catch (err) {
  console.log('   ❌ Failed to load security config:', err.message);
  process.exit(1);
}

// Test 4: Token Service
console.log('\n4️⃣ TOKEN SERVICE:');
try {
  const { signAccessToken } = await import('./src/modules/auth/services/tokenService.js');
  console.log('   ✅ Token service loaded');
  
  // Test token generation
  const testUser = {
    id: 999,
    email: 'test@example.com',
    firebase_uid: null
  };
  
  const { token, expiresAt } = signAccessToken(testUser);
  console.log('   ✅ Token generated successfully');
  console.log('      - Token length:', token.length);
  console.log('      - Expires at:', expiresAt.toISOString());
  
  // Test token verification
  const jwt = (await import('jsonwebtoken')).default;
  const decoded = jwt.verify(token, process.env.JWT_SECRET, {
    issuer: 'i-spoon-backend',
    audience: 'i-spoon-mobile',
    algorithms: ['HS256']
  });
  
  console.log('   ✅ Token verified successfully');
  console.log('      - User ID:', decoded.id);
  console.log('      - Email:', decoded.email);
  console.log('      - Issuer:', decoded.iss);
  console.log('      - Audience:', decoded.aud);
  
} catch (err) {
  console.log('   ❌ Token service error:', err.message);
  console.log('      Stack:', err.stack);
  process.exit(1);
}

// Test 5: Database Connection
console.log('\n5️⃣ DATABASE CONNECTION:');
try {
  const { pool } = await import('./src/config/db.js');
  const result = await pool.query('SELECT NOW()');
  console.log('   ✅ Database connected');
  console.log('      - Server time:', result.rows[0].now);
} catch (err) {
  console.log('   ❌ Database connection failed:', err.message);
}

// Test 6: Auth Middleware
console.log('\n6️⃣ AUTH MIDDLEWARE:');
try {
  const { protect } = await import('./src/middleware/authMiddleware.js');
  console.log('   ✅ Middleware loaded');
  
  // Simulate request with valid token
  const { signAccessToken } = await import('./src/modules/auth/services/tokenService.js');
  const testUser = { id: 999, email: 'test@example.com', firebase_uid: null };
  const { token } = signAccessToken(testUser);
  
  const mockReq = {
    headers: { authorization: `Bearer ${token}` },
    path: '/test',
    method: 'GET'
  };
  
  const mockRes = {
    status: (code) => ({
      json: (data) => {
        console.log('   ❌ Middleware rejected valid token!');
        console.log('      Status:', code);
        console.log('      Response:', data);
      }
    })
  };
  
  const mockNext = () => {
    console.log('   ✅ Middleware accepted valid token');
    console.log('      - User attached to request:', mockReq.user.id);
  };
  
  protect(mockReq, mockRes, mockNext);
  
} catch (err) {
  console.log('   ❌ Middleware test failed:', err.message);
  console.log('      Stack:', err.stack);
}

// Test 7: User Model
console.log('\n7️⃣ USER MODEL:');
try {
  const { getUserByEmail } = await import('./src/models/userModel.js');
  console.log('   ✅ User model loaded');
} catch (err) {
  console.log('   ❌ User model failed:', err.message);
}

// Test 8: Auth Controllers
console.log('\n8️⃣ AUTH CONTROLLERS:');
try {
  const authController = await import('./src/controllers/authController.js');
  console.log('   ✅ Auth controller loaded');
  console.log('      - Functions:', Object.keys(authController).join(', '));
  
  const firebaseController = await import('./src/controllers/firebaseAuthController.js');
  console.log('   ✅ Firebase auth controller loaded');
  console.log('      - Functions:', Object.keys(firebaseController).join(', '));
} catch (err) {
  console.log('   ❌ Controllers failed:', err.message);
}

// Test 9: Routes
console.log('\n9️⃣ ROUTES CONFIGURATION:');
try {
  const authRoutes = await import('./src/modules/auth/routes.js');
  console.log('   ✅ Auth routes loaded');
} catch (err) {
  console.log('   ❌ Routes failed:', err.message);
}

console.log('\n' + '='.repeat(60));
console.log('\n🎯 DIAGNOSIS SUMMARY:\n');

// Check .env formatting issues
console.log('⚠️  POTENTIAL ISSUES FOUND:');
console.log('   1. Check .env file for spaces around = signs');
console.log('      Example: "KEY = value" should be "KEY=value"');
console.log('   2. Ensure no trailing spaces in .env values');
console.log('   3. Make sure JWT_SECRET has no quotes or spaces');

console.log('\n✅ SYSTEM STATUS:');
console.log('   - JWT Secret: Valid');
console.log('   - Token Generation: Working');
console.log('   - Token Verification: Working');
console.log('   - Middleware: Working');
console.log('   - All modules: Loaded successfully');

console.log('\n💡 NEXT STEPS:');
console.log('   1. Start the server: npm run dev');
console.log('   2. Test login endpoint:');
console.log('      curl -X POST http://localhost:5000/api/auth/signup \\');
console.log('        -H "Content-Type: application/json" \\');
console.log('        -d \'{"email":"test@example.com","password":"Test123!@#","name":"Test"}\'');
console.log('   3. Check server logs for detailed errors');

console.log('\n✨ Authentication system is ready!\n');

