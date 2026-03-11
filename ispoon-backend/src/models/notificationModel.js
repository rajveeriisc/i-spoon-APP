import { pool } from "../config/db.js";

/**
 * Notification Model - Database operations for notifications (V2 Schema)
 */

// Create notification
export const createNotification = async (notificationData) => {
    const { user_id, title, body, type, priority = 'DEFAULT', data = {} } = notificationData;
    const res = await pool.query(
        `INSERT INTO notifications (user_id, title, body, type, priority, data)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [user_id, title, body, type, priority, JSON.stringify(data)]
    );
    return res.rows[0];
};

// Mark notification as read
export const markNotificationRead = async (notificationId, userId) => {
    const res = await pool.query(
        `UPDATE notifications SET read = TRUE WHERE id = $1 AND user_id = $2 RETURNING *`,
        [notificationId, userId]
    );
    return res.rows[0];
};

// Get notification history for user
export const getUserNotificationHistory = async (userId, limit = 50, offset = 0) => {
    const res = await pool.query(
        `SELECT * FROM notifications 
         WHERE user_id = $1 
         ORDER BY created_at DESC 
         LIMIT $2 OFFSET $3`,
        [userId, limit, offset]
    );
    return res.rows;
};

// Add FCM Token
export const addFCMToken = async (userId, token) => {
    const res = await pool.query(
        `INSERT INTO fcm_tokens (user_id, token)
         VALUES ($1, $2)
         ON CONFLICT (user_id, token) DO UPDATE SET last_used_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [userId, token]
    );
    return res.rows[0];
};

// Get FCM Tokens for User
export const getUserFCMTokens = async (userId) => {
    const res = await pool.query(
        `SELECT token FROM fcm_tokens WHERE user_id = $1`,
        [userId]
    );
    return res.rows.map(row => row.token);
};

// Remove FCM Token
export const removeFCMToken = async (token) => {
    await pool.query(`DELETE FROM fcm_tokens WHERE token = $1`, [token]);
};
