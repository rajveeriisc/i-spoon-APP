import { pool } from "../config/db.js";

/**
 * Analytics Repository
 * Handles queries for aggregated data, summaries, and trends
 */

/**
 * Get user dashboard summary from materialized view
 * @param {number} userId - User ID
 * @returns {Promise<Object>} Dashboard data
 */
export const getUserDashboard = async (userId) => {
    const result = await pool.query(
        `SELECT * FROM mv_user_dashboard WHERE user_id = $1`,
        [userId]
    );
    return result.rows[0] || null;
};

/**
 * Get daily bite summaries for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days to retrieve (default: 30)
 * @returns {Promise<Array>} Array of daily summaries
 */
export const getDailyBiteSummaries = async (userId, days = 30) => {
    const result = await pool.query(
        `SELECT *
     FROM daily_bite_summaries
     WHERE user_id = $1
       AND summary_date > CURRENT_DATE - $2::integer
     ORDER BY summary_date DESC`,
        [userId, days]
    );
    return result.rows;
};

/**
 * Get daily tremor summaries for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days to retrieve (default: 30)
 * @returns {Promise<Array>} Array of daily tremor summaries
 */
export const getDailyTremorSummaries = async (userId, days = 30) => {
    const result = await pool.query(
        `SELECT *
     FROM daily_tremor_summaries
     WHERE user_id = $1
       AND summary_date > CURRENT_DATE - $2::integer
     ORDER BY summary_date DESC`,
        [userId, days]
    );
    return result.rows;
};

/**
 * Get weekly meal trends for a user
 * @param {number} userId - User ID
 * @param {number} weeks - Number of weeks to retrieve (default: 12)
 * @returns {Promise<Array>} Array of weekly trends
 */
export const getWeeklyMealTrends = async (userId, weeks = 12) => {
    const result = await pool.query(
        `SELECT *
     FROM mv_weekly_meal_trends
     WHERE user_id = $1
       AND week_start > CURRENT_DATE - ($2::integer * 7)
     ORDER BY week_start DESC`,
        [userId, weeks]
    );
    return result.rows;
};

/**
 * Get daily activity summary for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days to retrieve (default: 30)
 * @returns {Promise<Array>} Array of daily activities
 */
export const getDailyActivitySummary = async (userId, days = 30) => {
    const result = await pool.query(
        `SELECT *
     FROM mv_daily_activity_summary
     WHERE user_id = $1
       AND activity_date > CURRENT_DATE - $2::integer
     ORDER BY activity_date DESC`,
        [userId, days]
    );
    return result.rows;
};

/**
 * Get trend cache data
 * @param {number} userId - User ID
 * @param {string} metric - Metric name (e.g., 'bites', 'tremor')
 * @param {Date} periodStart - Start date
 * @param {Date} periodEnd - End date
 * @param {string} timeBucket - Time bucket interval (e.g., '1 day')
 * @returns {Promise<Object>} Trend cache data
 */
export const getTrendCache = async (userId, metric, periodStart, periodEnd, timeBucket = '1 day') => {
    const result = await pool.query(
        `SELECT payload, computed_at
     FROM trend_caches
     WHERE user_id = $1
       AND metric = $2
       AND period_start = $3
       AND period_end = $4
       AND time_bucket = $5::interval
     LIMIT 1`,
        [userId, metric, periodStart, periodEnd, timeBucket]
    );
    return result.rows[0] || null;
};

/**
 * upsert trend cache
 * @param {Object} params - Cache parameters
 * @returns {Promise<Object>} Upserted cache entry
 */
export const upsertTrendCache = async ({ userId, metric, periodStart, periodEnd, timeBucket, payload }) => {
    const result = await pool.query(
        `INSERT INTO trend_caches (user_id, metric, period_start, period_end, time_bucket, payload, computed_at)
     VALUES ($1, $2, $3, $4, $5::interval, $6, NOW())
     ON CONFLICT (user_id, metric, period_start, period_end, time_bucket)
     DO UPDATE SET
       payload = EXCLUDED.payload,
       computed_at = NOW()
     RETURNING *`,
        [userId, metric, periodStart, periodEnd, timeBucket, JSON.stringify(payload)]
    );
    return result.rows[0];
};

/**
 * Get meal statistics for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days (default: 30)
 * @returns {Promise<Object>} Meal statistics
 */
export const getMealStatistics = async (userId, days = 30) => {
    const result = await pool.query(
        `SELECT
       COUNT(*) AS total_meals,
       SUM(total_bites) AS total_bites,
       AVG(total_bites) AS avg_bites_per_meal,
       AVG(avg_bite_interval_seconds) AS avg_eating_pace,
       AVG(tremor_index) AS avg_tremor_index,
       SUM(anomaly_count) AS total_anomalies
     FROM meals
     WHERE user_id = $1
       AND started_at > NOW() - ($2::integer || ' days')::interval`,
        [userId, days]
    );
    return result.rows[0];
};

/**
 * Get goal achievement stats
 * @param {number} userId - User ID
 * @param {number} days - Number of days (default: 30)
 * @returns {Promise<Object>} Goal achievement data
 */
export const getGoalAchievement = async (userId, days = 30) => {
    const result = await pool.query(
        `SELECT
       COUNT(*) AS total_days,
       SUM(CASE WHEN goal_met THEN 1 ELSE 0 END) AS days_goal_met,
       ROUND(100.0 * SUM(CASE WHEN goal_met THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS achievement_percentage
     FROM daily_bite_summaries
     WHERE user_id = $1
       AND summary_date > CURRENT_DATE - $2::integer`,
        [userId, days]
    );
    return result.rows[0];
};

/**
 * Refresh materialized views
 * @returns {Promise<void>}
 */
export const refreshMaterializedViews = async () => {
    await pool.query('SELECT refresh_all_materialized_views()');
};

/**
 * Get comprehensive user analytics
 * @param {number} userId - User ID
 * @returns {Promise<Object>} Complete analytics data
 */
export const getComprehensiveAnalytics = async (userId) => {
    const [dashboard, dailyBites, dailyTremor, mealStats, goalStats] = await Promise.all([
        getUserDashboard(userId),
        getDailyBiteSummaries(userId, 30),
        getDailyTremorSummaries(userId, 30),
        getMealStatistics(userId, 30),
        getGoalAchievement(userId, 30),
    ]);

    return {
        dashboard,
        dailySummaries: {
            bites: dailyBites,
            tremor: dailyTremor,
        },
        mealStatistics: mealStats,
        goalAchievement: goalStats,
    };
};
