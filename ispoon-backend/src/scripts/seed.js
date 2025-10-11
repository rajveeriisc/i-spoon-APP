import dotenv from "dotenv";
import bcrypt from "bcrypt";
import { pool } from "../config/db.js";

dotenv.config();

async function ensureUsersTable() {
  const createSql = `
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `;
  await pool.query(createSql);
}

async function insertSampleUsers() {
  const sampleUsers = [
    { email: "alice@example.com", password: "Password123!" },
    { email: "bob@example.com", password: "Password123!" },
    { email: "charlie@example.com", password: "Password123!" }
  ];

  for (const user of sampleUsers) {
    const hashed = await bcrypt.hash(user.password, 10);
    await pool.query(
      `INSERT INTO users (email, password) VALUES ($1, $2)
       ON CONFLICT (email) DO NOTHING`,
      [user.email.toLowerCase(), hashed]
    );
  }
}

async function main() {
  try {
    if (!process.env.DATABASE_URL) {
      console.error("❌ DATABASE_URL is not set. Please add it to .env");
      process.exit(1);
    }

    await ensureUsersTable();
    await insertSampleUsers();
    console.log("✅ Seed completed. Users inserted (if not existing):");
    console.log(
      "- alice@example.com / Password123!\n- bob@example.com / Password123!\n- charlie@example.com / Password123!"
    );
    process.exit(0);
  } catch (err) {
    console.error("❌ Seed failed:", err.message);
    process.exit(1);
  }
}

main();


