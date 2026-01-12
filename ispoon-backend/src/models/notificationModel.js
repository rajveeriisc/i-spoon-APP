import { pool } from "../config/db.js";

/**
 * Notification Model - Database operations for notifications
 */

// Get all active notification templates
export const getAllTemplates = async () => {
    const res = await pool.query(
        `SELECT * FROM notification_templates WHERE is_active = TRUE ORDER BY category, priority`
    );
    return res.rows;
};

// Get template by type
export const getTemplateByType = async (type) => {
    const res = await pool.query(
        `SELECT * FROM notification_templates WHERE type = $1 AND is_active = TRUE`,
        [type]
    );
    return res.rows[0];
};

// Get user notification preferences
export const getUserPreferences = async (userId) => {
    const res = await pool.query(
        `SELECT * FROM user_notification_preferences WHERE user_id = $1`,
        [userId]
    );
    return res.rows[0];
};

// Update user preferences
export const updateUserPreferences = async (userId, preferences) => {
    const {
        enabled,
        quiet_hours_start,
        quiet_hours_end,
        health_alerts_enabled,
        achievement_enabled,
        engagement_enabled,
        system_alerts_enabled,
        max_daily_notifications,
        weekly_digest_enabled,
        weekly_digest_day,
        weekly_digest_time,
        fcm_token
    } = preferences;

    const res = await pool.query(
        `UPDATE user_notification_preferences 
         SET enabled = COALESCE($2, enabled),
             quiet_hours_start = COALESCE($3, quiet_hours_start),
             quiet_hours_end = COALESCE($4, quiet_hours_end),
             health_alerts_enabled = COALESCE($5, health_alerts_enabled),
             achievement_enabled = COALESCE($6, achievement_enabled),
             engagement_enabled = COALESCE($7, engagement_enabled),
             system_alerts_enabled = COALESCE($8, system_alerts_enabled),
             max_daily_notifications = COALESCE($9, max_daily_notifications),
             weekly_digest_enabled = COALESCE($10, weekly_digest_enabled),
             weekly_digest_day = COALESCE($11, weekly_digest_day),
             weekly_digest_time = COALESCE($12, weekly_digest_time),
             fcm_token = COALESCE($13, fcm_token),
             fcm_token_updated_at = CASE WHEN $13 IS NOT NULL THEN NOW() ELSE fcm_token_updated_at END,
             updated_at = NOW()
         WHERE user_id = $1
         RETURNING *`,
        [
            userId, enabled, quiet_hours_start, quiet_hours_end,
            health_alerts_enabled, achievement_enabled, engagement_enabled, system_alerts_enabled,
            max_daily_notifications, weekly_digest_enabled, weekly_digest_day, weekly_digest_time,
            fcm_token
        ]
    );
    return res.rows[0];
};

// Create notification in history
export const createNotification = async (notificationData) => {
    const {
        user_id,
        template_id,
        type,
        priority,
        title,
        body,
        action_type,
        action_data,
        scheduled_for,
        trigger_source,
        delivery_method = 'push'
    } = notificationData;

    const res = await pool.query(
        `INSERT INTO notification_history (
            user_id, template_id, type, priority, title, body,
            action_type, action_data, scheduled_for, trigger_source, delivery_method
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
         RETURNING *`,
        [
            user_id, template_id, type, priority, title, body,
            action_type, action_data, scheduled_for, trigger_source, delivery_method
        ]
    );
    return res.rows[0];
};

// Update notification delivery status
export const updateNotificationStatus = async (notificationId, status, errorMessage = null) => {
    const timestampField = {
        'sent': 'sent_at',
        'delivered': 'delivered_at',
        'failed': 'sent_at' // Set sent_at even for failures
    }[status] || null;

    const query = timestampField
        ? `UPDATE notification_history 
           SET delivery_status = $2, ${timestampField} = NOW(), error_message = $3 
           WHERE id = $1 RETURNING *`
        : `UPDATE notification_history 
           SET delivery_status = $2, error_message = $3 
           WHERE id = $1 RETURNING *`;

    const res = await pool.query(query, [notificationId, status, errorMessage]);
    return res.rows[0];
};

// Mark notification as opened
export const markNotificationOpened = async (notificationId) => {
    const res = await pool.query(
        `UPDATE notification_history SET opened_at = NOW() WHERE id = $1 RETURNING *`,
        [notificationId]
    );
    return res.rows[0];
};

// Mark notification action taken
export const markNotificationActionTaken = async (notificationId) => {
    const res = await pool.query(
        `UPDATE notification_history SET action_taken_at = NOW() WHERE id = $1 RETURNING *`,
        [notificationId]
    );
    return res.rows[0];
};

// Get notification history for user
export const getUserNotificationHistory = async (userId, limit = 50, offset = 0) => {
    const res = await pool.query(
        `SELECT * FROM notification_history 
         WHERE user_id = $1 
         ORDER BY created_at DESC 
         LIMIT $2 OFFSET $3`,
        [userId, limit, offset]
    );
    return res.rows;
};

// Check if notification can be sent (uses DB function)
export const canSendNotification = async (userId, type, priority) => {
    const res = await pool.query(
        `SELECT can_send_notification($1, $2, $3) as can_send`,
        [userId, type, priority]
    );
    return res.rows[0].can_send;
};

// Increment throttle counter
export const incrementThrottleCounter = async (userId, type) => {
    await pool.query(
        `SELECT increment_throttle_counter($1, $2)`,
        [userId, type]
    );
};

// Get pending notifications (for batch processing)
export const getPendingNotifications = async (limit = 100) => {
    const res = await pool.query(
        `SELECT * FROM notification_history 
         WHERE delivery_status = 'pending' 
           AND (scheduled_for IS NULL OR scheduled_for <= NOW())
         ORDER BY priority DESC, created_at ASC
         LIMIT $1`,
        [limit]
    );
    return res.rows;
};

// Clean up old notifications (older than 90 days)
export const cleanupOldNotifications = async () => {
    const res = await pool.query(
        `DELETE FROM notification_history 
         WHERE created_at < NOW() - INTERVAL '90 days' 
         RETURNING id`
    );
    return res.rowCount;
};
