import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function seed() {
  const { rows: users } = await pool.query(`SELECT id FROM users ORDER BY id ASC LIMIT 5`);
  const now = new Date();
  for (const u of users) {
    for (let d = 0; d < 14; d++) {
      const day = new Date(now.getTime() - d * 86400000);
      const total = Math.floor(Math.random() * 250);
      if (total === 0) continue;
      await pool.query(
        `INSERT INTO bites (user_id, amount, occurred_at)
         SELECT $1, 1, $2 FROM generate_series(1, $3)
         ON CONFLICT DO NOTHING`,
        [u.id, day, total]
      );
    }
  }
  console.log("✅ Seed complete: bites for ", users.length, "users");
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Seed failed:", err.message);
    process.exit(1);
  });


