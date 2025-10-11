import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function migrate() {
  const sql = `
    CREATE TABLE IF NOT EXISTS bites (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      amount INTEGER NOT NULL DEFAULT 1 CHECK (amount > 0),
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_bites_user_day ON bites(user_id, occurred_at);
  `;
  await pool.query(sql);
  console.log("✅ Migration complete: bites table ready");
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Migration failed:", err.message);
    process.exit(1);
  });


