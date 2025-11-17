import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

/**
 * General seed script placeholder
 * Use specific seed scripts instead:
 * - npm run seed:bites (seed bite data)
 * - npm run migrate (setup database schema)
 */
async function main() {
  try {
    if (!process.env.DATABASE_URL) {
      console.error("❌ DATABASE_URL is not set. Please add it to .env");
      process.exit(1);
    }

    console.log("✅ Database connection verified");
    console.log("\nAvailable seed commands:");
    console.log("  npm run seed:bites:dev     - Seed bite data (development)");
    console.log("  npm run seed:bites:staging - Seed bite data (staging)");
    console.log("  npm run seed:bites         - Seed bite data (all users)");
    console.log("  npm run migrate            - Run database migrations");
    
    process.exit(0);
  } catch (err) {
    console.error("❌ Database connection failed:", err.message);
    process.exit(1);
  }
}

main();


