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
});

// Log and avoid crashing on idle client errors
pool.on("error", (err) => {
  console.error("❌ Postgres pool error (idle client):", err.message);
});

// Lightweight startup health check without holding a client
pool
  .query("SELECT 1")
  .then(() => console.log("✅ Postgres reachable"))
  .catch((err) => console.error("❌ Postgres startup check failed:", err.message));
  