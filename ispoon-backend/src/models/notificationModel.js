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
        `INSERT INTO user_notification_preferences (
            user_id, enabled, quiet_hours_start, quiet_hours_end,
            health_alerts_enabled, achievement_enabled, engagement_enabled, system_alerts_enabled,
            max_daily_notifications, weekly_digest_enabled, weekly_digest_day, weekly_digest_time,
            fcm_token, fcm_token_updated_at, updated_at
        ) VALUES (
            $1, 
            COALESCE($2, true), 
            COALESCE($3, '22:00'::TIME), 
            COALESCE($4, '07:00'::TIME),
            COALESCE($5, true),
            COALESCE($6, true),
            COALESCE($7, true),
            COALESCE($8, true),
            COALESCE($9, 10),
            COALESCE($10, true),
            COALESCE($11, 0),
            COALESCE($12, '09:00'::TIME),
            $13::TEXT,
            CASE WHEN $13 IS NOT NULL THEN NOW() ELSE NULL END,
            NOW()
        )
        ON CONFLICT (user_id) DO UPDATE 
        SET enabled = COALESCE($2, user_notification_preferences.enabled),
            quiet_hours_start = COALESCE($3, user_notification_preferences.quiet_hours_start),
            quiet_hours_end = COALESCE($4, user_notification_preferences.quiet_hours_end),
            health_alerts_enabled = COALESCE($5, user_notification_preferences.health_alerts_enabled),
            achievement_enabled = COALESCE($6, user_notification_preferences.achievement_enabled),
            engagement_enabled = COALESCE($7, user_notification_preferences.engagement_enabled),
            system_alerts_enabled = COALESCE($8, user_notification_preferences.system_alerts_enabled),
            max_daily_notifications = COALESCE($9, user_notification_preferences.max_daily_notifications),
            weekly_digest_enabled = COALESCE($10, user_notification_preferences.weekly_digest_enabled),
            weekly_digest_day = COALESCE($11, user_notification_preferences.weekly_digest_day),
            weekly_digest_time = COALESCE($12, user_notification_preferences.weekly_digest_time),
            fcm_token = COALESCE($13, user_notification_preferences.fcm_token),
            fcm_token_updated_at = CASE WHEN $13 IS NOT NULL THEN NOW() ELSE user_notification_preferences.fcm_token_updated_at END,
            updated_at = NOW()
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
