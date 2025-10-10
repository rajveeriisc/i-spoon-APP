import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function migrate() {
  const sql = `
    CREATE EXTENSION IF NOT EXISTS citext;
    ALTER TABLE IF EXISTS users
      ALTER COLUMN email TYPE citext,
      ADD CONSTRAINT users_email_unique UNIQUE (email);
    ALTER TABLE IF EXISTS users
      ALTER COLUMN updated_at SET DEFAULT NOW();
  `;
  await pool.query(sql);
  console.log("✅ Migration complete: users constraints and defaults");
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Migration failed:", err.message);
    process.exit(1);
  });


