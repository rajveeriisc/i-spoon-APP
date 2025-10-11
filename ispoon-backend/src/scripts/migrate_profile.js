import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function migrate() {
  const sql = `
    ALTER TABLE IF EXISTS users
      ADD COLUMN IF NOT EXISTS name TEXT,
      ADD COLUMN IF NOT EXISTS phone TEXT,
      ADD COLUMN IF NOT EXISTS location TEXT,
      ADD COLUMN IF NOT EXISTS bio TEXT,
      ADD COLUMN IF NOT EXISTS diet_type TEXT,
      ADD COLUMN IF NOT EXISTS activity_level TEXT,
      ADD COLUMN IF NOT EXISTS allergies TEXT[],
      ADD COLUMN IF NOT EXISTS daily_goal INTEGER,
      ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN,
      ADD COLUMN IF NOT EXISTS emergency_contact TEXT,
      ADD COLUMN IF NOT EXISTS avatar_url TEXT,
      ADD COLUMN IF NOT EXISTS reset_token TEXT,
      ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMPTZ,
      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
  `;

  await pool.query(sql);
  console.log("✅ Migration complete: users profile columns ready");
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Migration failed:", err.message);
    process.exit(1);
  });


