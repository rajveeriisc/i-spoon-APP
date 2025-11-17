import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

function parseMs(input, fallbackMs) {
  if (!input) return fallbackMs;
  const m = String(input).trim().match(/^(\d+)\s*(ms|s|m|h|d)$/i);
  if (!m) return fallbackMs;
  const n = Number(m[1]);
  const unit = m[2].toLowerCase();
  const mult = unit === 'ms' ? 1 : unit === 's' ? 1000 : unit === 'm' ? 60000 : unit === 'h' ? 3600000 : 86400000;
  return n * mult;
}

async function cleanupOldData() {
  try {
    console.log("Starting data cleanup...");
    const retentionMs = parseMs(process.env.RESET_TOKEN_RETENTION || "24h", 24 * 3600 * 1000);
    const { rowCount: resetTokensCleaned } = await pool.query(
      `UPDATE users SET reset_token = NULL, reset_token_expires_at = NULL
       WHERE reset_token IS NOT NULL AND reset_token_expires_at < NOW() - ($1::bigint || ' milliseconds')::interval`,
      [retentionMs]
    );
    console.log(`Cleaned ${resetTokensCleaned} expired password reset tokens`);
    console.log("✅ Data cleanup completed successfully");
    process.exit(0);
  } catch (error) {
    console.error("❌ Data cleanup failed:", error.message);
    process.exit(1);
  }
}

cleanupOldData();