import { pool } from "../config/db.js";

const checkTokens = async () => {
    try {
        console.log("Checking users and tokens...");
        const res = await pool.query(`
      SELECT 
        u.id, 
        u.email, 
        unp.fcm_token, 
        unp.system_alerts_enabled,
        LENGTH(unp.fcm_token) as token_len 
      FROM users u
      LEFT JOIN user_notification_preferences unp ON u.id = unp.user_id
    `);

        console.table(res.rows.map(r => ({
            id: r.id,
            email: r.email,
            has_token: !!r.fcm_token,
            token_start: r.fcm_token ? r.fcm_token.substring(0, 10) + '...' : 'N/A'
        })));

        process.exit(0);
    } catch (error) {
        console.error("Error:", error);
        process.exit(1);
    }
};

checkTokens();
