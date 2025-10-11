import pkg from "pg";
import dotenv from "dotenv";
dotenv.config();

const { Pool } = pkg;

// ✅ Connect to NeonDB PostgreSQL (secure SSL)
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
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