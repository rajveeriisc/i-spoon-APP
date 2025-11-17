import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function ensureMigrationsTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id BIGSERIAL PRIMARY KEY,
      filename TEXT UNIQUE NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

async function getApplied() {
  const res = await pool.query(`SELECT filename FROM schema_migrations`);
  const set = new Set(res.rows.map((r) => r.filename));
  return set;
}
    
async function applyMigration(filename, sql) {
  console.log(`→ Applying ${filename} ...`);
  try {
    await pool.query("BEGIN");
    await pool.query(sql);
    await pool.query("INSERT INTO schema_migrations (filename) VALUES ($1)", [filename]);
    await pool.query("COMMIT");
    console.log(`✅ Applied ${filename}`);
  } catch (err) {
    await pool.query("ROLLBACK");
    console.error(`❌ Migration failed (${filename}):`, err.message);
    process.exit(1);
  }
}

async function run() {
  try {
    if (!process.env.DATABASE_URL) {
      console.error("❌ DATABASE_URL is not set. Please add it to .env");
      process.exit(1);
    }

    const migrationsDir = path.join(process.cwd(), "src", "migrations");
    if (!fs.existsSync(migrationsDir)) {
      console.log("No migrations directory found; nothing to do.");
      process.exit(0);
    }

    await ensureMigrationsTable();
    const applied = await getApplied();

    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".sql"))
      .sort();

    for (const f of files) {
      if (applied.has(f)) continue;
      const sql = fs.readFileSync(path.join(migrationsDir, f), "utf8");
      if (!sql.trim()) continue;
      await applyMigration(f, sql);
    }

    console.log("🏁 Migrations complete");
    process.exit(0);
  } catch (err) {
    console.error("❌ migrate.js failed:", err.message);
    process.exit(1);
  }
}

run();


