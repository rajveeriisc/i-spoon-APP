import { pool } from "../config/db.js";

const checkPrefs = async () => {
    try {
        console.log("Checking user_notification_preferences...");
        const res = await pool.query(`
      SELECT * FROM user_notification_preferences
    `);

        console.table(res.rows);
        process.exit(0);
    } catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
};

checkPrefs();
