import dotenv from 'dotenv';
dotenv.config();

const p = process.env;

console.log('=== Environment Variables Check ===');
console.log('FIREBASE_PROJECT_ID:', p.FIREBASE_PROJECT_ID || 'MISSING');
console.log('FIREBASE_CLIENT_EMAIL:', p.FIREBASE_CLIENT_EMAIL || 'MISSING');
console.log('FIREBASE_PRIVATE_KEY present:', !!p.FIREBASE_PRIVATE_KEY);
console.log('DATABASE_URL present:', !!p.DATABASE_URL);
console.log('JWT_SECRET present:', !!p.JWT_SECRET);
console.log('NODE_ENV:', p.NODE_ENV || 'development');

if (p.FIREBASE_PRIVATE_KEY) {
  const key = p.FIREBASE_PRIVATE_KEY;
  console.log('PRIVATE_KEY format check:');
  console.log('- Starts with PEM:', key.startsWith('-----BEGIN PRIVATE KEY-----'));
  console.log('- Contains literal \\n:', key.includes('\\n'));
  console.log('- Length:', key.length);
}
