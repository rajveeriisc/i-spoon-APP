import pkg from "pg";
import dotenv from "dotenv";
dotenv.config();

const { Pool } = pkg;

// Determine SSL dynamically: allow local Postgres without SSL, Neon/managed with SSL
const shouldUseSSL = (() => {
  const flag = String(process.env.DATABASE_SSL || process.env.PGSSLMODE || "").toLowerCase();
  if (flag === "1" || flag === "true" || flag === "require" || flag === "required") return true;
  try {
    const url = new URL(String(process.env.DATABASE_URL || ""));
    if (url.searchParams.get("sslmode") === "require") return true;
    return (url.hostname || "").includes("neon.tech");
  } catch (_) {
    return false;
  }
})();

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: shouldUseSSL ? { rejectUnauthorized: false } : false,
  // TODO: Enable certificate validation in production
  // Connection pool configuration
  max: 20, // Maximum pool size
  idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
  connectionTimeoutMillis: 10000, // Return error after 10 seconds if connection cannot be established
});

// Handle idle client errors and attempt recovery
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;
const baseReconnectDelay = 1000; // 1 second

pool.on("error", async (err) => {
  console.error("❌ Postgres pool error (idle client):", err.message);

  // Attempt to recover connection
  if (reconnectAttempts < maxReconnectAttempts) {
    reconnectAttempts++;
    const delay = baseReconnectDelay * Math.pow(2, reconnectAttempts - 1); // Exponential backoff
    console.log(`Attempting to reconnect in ${delay}ms (attempt ${reconnectAttempts}/${maxReconnectAttempts})`);

    setTimeout(async () => {
      try {
        await pool.query("SELECT 1");
        console.log("✅ Database connection recovered");
        reconnectAttempts = 0; // Reset counter on success
      } catch (retryErr) {
        console.error("❌ Reconnection failed:", retryErr.message);
      }
    }, delay);
  } else {
    console.error("❌ Max reconnection attempts reached. Manual intervention required.");
  }
});

// Lightweight startup health check - properly awaited
(async () => {
  try {
    await pool.query("SELECT 1");
    console.log("✅ Postgres reachable");
  } catch (err) {
    console.error("❌ Postgres startup check failed:", err.message);
    console.error("⚠️  Server will continue but database operations will fail");
  }
})();
