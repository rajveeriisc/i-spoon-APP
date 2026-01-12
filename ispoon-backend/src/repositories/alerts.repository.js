import { pool } from "../config/db.js";

/**
 * Alerts \u0026 Recommendations Repository
 * Handles notifications, alerts, and AI recommendations
 */

// ============================================================================
// ALERTS
// ============================================================================

/**
 * Create a new alert
 * @param {Object} params - Alert parameters
 * @returns {Promise<Object>} Created alert
 */
export const createAlert = async ({ userId, deviceSessionId = null, alertType, status = 'pending', message }) => {
    const result = await pool.query(
        `INSERT INTO alerts (user_id, device_session_id, alert_type, status, message, created_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     RETURNING *`,
        [userId, deviceSessionId, alertType, status, message]
    );
    return result.rows[0];
};

/**
 * Get alerts for a user
 * @param {number} userId - User ID
 * @param {Object} filters - Optional filters
 * @returns {Promise<Array>} Array of alerts
 */
export const getUserAlerts = async (userId, { status = null, alertType = null, limit = 50 } = {}) => {
    let query = `
    SELECT * FROM alerts
    WHERE user_id = $1
  `;
    const params = [userId];
    let paramIndex = 2;

    if (status) {
        query += ` AND status = $${paramIndex++}`;
        params.push(status);
    }

    if (alertType) {
        query += ` AND alert_type = $${paramIndex++}`;
        params.push(alertType);
    }

    query += ` ORDER BY created_at DESC LIMIT $${paramIndex}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows;
};

/**
 * Update alert status
 * @param {number} alertId - Alert ID
 * @param {string} status - New status
 * @returns {Promise<Object>} Updated alert
 */
export const updateAlertStatus = async (alertId, status) => {
    const statusColumn = status === 'sent' ? 'sent_at' :
        status === 'read' || status === 'dismissed' ? 'acknowledged_at' : null;

    let query = `UPDATE alerts SET status = $1`;
    const params = [status, alertId];

    if (statusColumn) {
        query += `, ${statusColumn} = NOW()`;
    }

    query += ` WHERE id = $2 RETURNING *`;

    const result = await pool.query(query, params);
    return result.rows[0];
};

/**
 * Mark alert as read
 * @param {number} alertId - Alert ID
 * @returns {Promise<Object>} Updated alert
 */
export const markAlertAsRead = async (alertId) => {
    return updateAlertStatus(alertId, 'read');
};

/**
 * Get pending alerts count
 * @param {number} userId - User ID
 * @returns {Promise<number>} Count of pending alerts
 */
export const getPendingAlertsCount = async (userId) => {
    const result = await pool.query(
        `SELECT COUNT(*) as count FROM alerts
     WHERE user_id = $1 AND status IN ('pending', 'sent')`,
        [userId]
    );
    return parseInt(result.rows[0].count);
};

/**
 * Delete old alerts
 * @param {number} daysOld - Delete alerts older than this many days
 * @returns {Promise<number>} Number of deleted alerts
 */
export const deleteOldAlerts = async (daysOld = 90) => {
    const result = await pool.query(
        `DELETE FROM alerts
     WHERE created_at < NOW() - ($1::integer || ' days')::interval
       AND status IN ('read', 'dismissed')`,
        [daysOld]
    );
    return result.rowCount;
};

// ============================================================================
// RECOMMENDATIONS
// ============================================================================

/**
 * Create a recommendation
 * @param {Object} params - Recommendation parameters
 * @returns {Promise<Object>} Created recommendation
 */
export const createRecommendation = async ({
    userId,
    mealId = null,
    recommendationType,
    severity = 'info',
    markdownBody,
    expiresAt = null,
}) => {
    const result = await pool.query(
        `INSERT INTO recommendations (
       user_id, meal_id, recommendation_type, severity,
       markdown_body, created_at, expires_at
     )
     VALUES ($1, $2, $3, $4, $5, NOW(), $6)
     RETURNING *`,
        [userId, mealId, recommendationType, severity, markdownBody, expiresAt]
    );
    return result.rows[0];
};

/**
 * Get recommendations for a user
 * @param {number} userId - User ID
 * @param {Object} filters - Optional filters
 * @returns {Promise<Array>} Array of recommendations
 */
export const getUserRecommendations = async (userId, {
    recommendationType = null,
    severity = null,
    unreadOnly = false,
    limit = 20,
} = {}) => {
    let query = `
    SELECT * FROM recommendations
    WHERE user_id = $1
  `;
    const params = [userId];
    let paramIndex = 2;

    if (recommendationType) {
        query += ` AND recommendation_type = $${paramIndex++}`;
        params.push(recommendationType);
    }

    if (severity) {
        query += ` AND severity = $${paramIndex++}`;
        params.push(severity);
    }

    if (unreadOnly) {
        query += ` AND read_at IS NULL`;
    }

    // Only show non-expired recommendations
    query += ` AND (expires_at IS NULL OR expires_at > NOW())`;

    query += ` ORDER BY severity DESC, created_at DESC LIMIT $${paramIndex}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows;
};

/**
 * Mark recommendation as read
 * @param {number} recommendationId - Recommendation ID
 * @returns {Promise<Object>} Updated recommendation
 */
export const markRecommendationAsRead = async (recommendationId) => {
    const result = await pool.query(
        `UPDATE recommendations
     SET read_at = NOW()
     WHERE id = $1 AND read_at IS NULL
     RETURNING *`,
        [recommendationId]
    );
    return result.rows[0];
};

/**
 * Mark recommendation as delivered
 * @param {number} recommendationId - Recommendation ID
 * @returns {Promise<Object>} Updated recommendation
 */
export const markRecommendationAsDelivered = async (recommendationId) => {
    const result = await pool.query(
        `UPDATE recommendations
     SET delivered_at = NOW()
     WHERE id = $1 AND delivered_at IS NULL
     RETURNING *`,
        [recommendationId]
    );
    return result.rows[0];
};

/**
 * Get unread recommendations count
 * @param {number} userId - User ID
 * @returns {Promise<number>} Count of unread recommendations
 */
export const getUnreadRecommendationsCount = async (userId) => {
    const result = await pool.query(
        `SELECT COUNT(*) as count FROM recommendations
     WHERE user_id = $1
       AND read_at IS NULL
       AND (expires_at IS NULL OR expires_at > NOW())`,
        [userId]
    );
    return parseInt(result.rows[0].count);
};

// ============================================================================
// NOTIFICATION PREFERENCES
// ============================================================================

/**
 * Get user notification preferences
 * @param {number} userId - User ID
 * @returns {Promise<Array>} Array of notification preferences
 */
export const getNotificationPreferences = async (userId) => {
    const result = await pool.query(
        `SELECT * FROM notification_preferences WHERE user_id = $1`,
        [userId]
    );
    return result.rows;
};

/**
 * upsert notification preference
 * @param {Object} params - Preference parameters
 * @returns {Promise<Object>} Upserted preference
 */
export const upsertNotificationPreference = async ({
    userId,
    alertType,
    channel = 'push',
    enabled = true,
}) => {
    const result = await pool.query(
        `INSERT INTO notification_preferences (user_id, alert_type, channel, enabled, created_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (user_id, alert_type, channel)
     DO UPDATE SET
       enabled = EXCLUDED.enabled,
       updated_at = NOW()
     RETURNING *`,
        [userId, alertType, channel, enabled]
    );
    return result.rows[0];
};

/**
 * Check if user has notification enabled for alert type
 * @param {number} userId - User ID
 * @param {string} alertType - Alert type
 * @param {string} channel - Notification channel
 * @returns {Promise<boolean>} Whether notification is enabled
 */
export const isNotificationEnabled = async (userId, alertType, channel = 'push') => {
    const result = await pool.query(
        `SELECT enabled FROM notification_preferences
     WHERE user_id = $1 AND alert_type = $2 AND channel = $3`,
        [userId, alertType, channel]
    );

    // Default to true if no preference exists
    return result.rows.length === 0 ? true : result.rows[0].enabled;
};
