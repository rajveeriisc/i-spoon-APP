import dotenv from "dotenv";
import { pool } from "../config/db.js";

dotenv.config();

async function cleanupOldData() {
  try {
    console.log("Starting data cleanup...");

    // Clean up old password reset tokens (older than 24 hours)
    const { rowCount: resetTokensCleaned } = await pool.query(
      `DELETE FROM users WHERE reset_token IS NOT NULL
       AND reset_token_expires_at < NOW() - INTERVAL '24 hours'`
    );
    console.log(`Cleaned ${resetTokensCleaned} expired password reset tokens`);

    // Clean up users with no recent activity (optional - uncomment if needed)
    // const { rowCount: oldUsersCleaned } = await pool.query(
    //   `DELETE FROM users WHERE created_at < NOW() - INTERVAL '1 year'
    //    AND last_login_at < NOW() - INTERVAL '6 months'`
    // );
    // console.log(`Cleaned ${oldUsersCleaned} inactive users`);

    // Clean up old avatar files (if any exist)
    // This would require file system access, implement if needed

    console.log("✅ Data cleanup completed successfully");
    process.exit(0);
  } catch (error) {
    console.error("❌ Data cleanup failed:", error.message);
    process.exit(1);
  }
}

cleanupOldData();
