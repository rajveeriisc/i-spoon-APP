import { pool } from "../config/db.js";

async function addSocialAuthFields() {
  try {
    console.log("Adding Firebase auth fields to users table...");

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255) UNIQUE;`
    );

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(50) DEFAULT 'email';`
    );

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;`
    );

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;`
    );

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();`
    );

    await pool.query(
      `ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();`
    );

    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);`
    );

    console.log("✅ Successfully ensured social auth fields exist");
    process.exit(0);
  } catch (error) {
    console.error("❌ Migration failed:", error.message);
    process.exit(1);
  }
}

addSocialAuthFields();

