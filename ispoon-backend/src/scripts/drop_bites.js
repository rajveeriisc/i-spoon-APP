import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function drop() {
  await pool.query(`DROP TABLE IF EXISTS bites CASCADE;`);
  console.log("✅ Dropped bites table");
}

drop()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Drop failed:", err.message);
    process.exit(1);
  });


