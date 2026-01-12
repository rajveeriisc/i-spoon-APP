import { pool } from "../config/db.js";

/**
 * Analytics Model - Handles daily_analytics queries for dashboard
 */

// Get daily analytics for a user (optimized for 3-month queries)
export const getDailyAnalytics = async (userId, startDate, endDate) => {
  const res = await pool.query(
    `SELECT 
      user_id, date, total_bites, avg_tremor_magnitude, max_tremor_magnitude,
      avg_tremor_frequency, meal_breakdown, tremor_distribution, total_eating_duration_min,
      updated_at
    FROM daily_analytics
    WHERE user_id = $1
      AND date >= $2
      AND date <= $3
    ORDER BY date ASC`,
    [userId, startDate, endDate]
  );

  return res.rows;
};

// Get analytics for a specific date
export const getAnalyticsForDate = async (userId, date) => {
  const res = await pool.query(
    `SELECT * FROM daily_analytics WHERE user_id = $1 AND date = $2`,
    [userId, date]
  );

  return res.rows[0];
};

// Get latest analytics (most recent day)
export const getLatestAnalytics = async (userId) => {
  const res = await pool.query(
    `SELECT * FROM daily_analytics 
     WHERE user_id = $1 
     ORDER BY date DESC 
     LIMIT 1`,
    [userId]
  );

  return res.rows[0];
};

// Get analytics summary for a period
export const getAnalyticsSummary = async (userId, startDate, endDate) => {
  const res = await pool.query(
    `SELECT 
      COUNT(*) as total_days,
      SUM(total_bites) as total_bites,
      AVG(total_bites) as avg_daily_bites,
      AVG(avg_tremor_magnitude) as avg_tremor,
      MAX(max_tremor_magnitude) as peak_tremor,
      SUM(total_eating_duration_min) as total_eating_time
    FROM daily_analytics
    WHERE user_id = $1
      AND date >= $2
      AND date <= $3`,
    [userId, startDate, endDate]
  );

  return res.rows[0];
};

// Get meal breakdown aggregated over a period
export const getMealBreakdownSummary = async (userId, startDate, endDate) => {
  const res = await pool.query(
    `SELECT 
      jsonb_object_agg(
        meal_type,
        total_bites
      ) as meal_breakdown
    FROM (
      SELECT 
        key as meal_type,
        SUM((value::text)::int) as total_bites
      FROM daily_analytics,
      jsonb_each(meal_breakdown)
      WHERE user_id = $1
        AND date >= $2
        AND date <= $3
      GROUP BY key
    ) subquery`,
    [userId, startDate, endDate]
  );

  return res.rows[0]?.meal_breakdown || {};
};

// Manually refresh analytics for a specific date (if trigger fails)
export const refreshAnalyticsForDate = async (userId, date) => {
  await pool.query(
    `INSERT INTO daily_analytics (
      user_id, date, total_bites, avg_tremor_magnitude, max_tremor_magnitude,
      meal_breakdown, total_eating_duration_min
    )
    SELECT 
      user_id,
      DATE(started_at) as date,
      SUM(total_bites) as total_bites,
      AVG(tremor_index) as avg_tremor_magnitude,
      MAX(tremor_index) as max_tremor_magnitude,
      jsonb_object_agg(COALESCE(meal_type, 'Unknown'), total_bites) as meal_breakdown,
      SUM(EXTRACT(EPOCH FROM (COALESCE(ended_at, started_at) - started_at)) / 60.0) as total_eating_duration_min
    FROM meals
    WHERE user_id = $1 AND DATE(started_at) = $2
    GROUP BY user_id, DATE(started_at)
    ON CONFLICT (user_id, date) DO UPDATE SET
      total_bites = EXCLUDED.total_bites,
      avg_tremor_magnitude = EXCLUDED.avg_tremor_magnitude,
      max_tremor_magnitude = EXCLUDED.max_tremor_magnitude,
      meal_breakdown = EXCLUDED.meal_breakdown,
      total_eating_duration_min = EXCLUDED.total_eating_duration_min,
      updated_at = NOW()`,
    [userId, date]
  );
};

// ============================================================================
// NEW: Daily Breakdown Table Queries
// ============================================================================

// Get daily bite breakdown for a user
export const getDailyBiteBreakdown = async (userId, startDate, endDate) => {
  const res = await pool.query(
    `SELECT 
      user_id, date, breakfast, lunch, dinner, snacks, total_bites,
      avg_pace_bpm, total_duration_min, avg_meal_duration_min, updated_at
    FROM daily_bite_breakdown
    WHERE user_id = $1
      AND date >= $2
      AND date <= $3
    ORDER BY date ASC`,
    [userId, startDate, endDate]
  );

  return res.rows;
};

// Get daily tremor breakdown for a user
export const getDailyTremorBreakdown = async (userId, startDate, endDate) => {
  const res = await pool.query(
    `SELECT 
      user_id, date, avg_magnitude, peak_magnitude, min_magnitude,
      avg_frequency_hz, dominant_level, level_value, total_tremor_events, updated_at
    FROM daily_tremor_breakdown
    WHERE user_id = $1
      AND date >= $2
      AND date <= $3
    ORDER BY date ASC`,
    [userId, startDate, endDate]
  );

  return res.rows;
};

// Get bite breakdown for a specific date
export const getBiteBreakdownForDate = async (userId, date) => {
  const res = await pool.query(
    `SELECT * FROM daily_bite_breakdown WHERE user_id = $1 AND date = $2`,
    [userId, date]
  );

  return res.rows[0];
};

// Get tremor breakdown for a specific date
export const getTremorBreakdownForDate = async (userId, date) => {
  const res = await pool.query(
    `SELECT * FROM daily_tremor_breakdown WHERE user_id = $1 AND date = $2`,
    [userId, date]
  );

  return res.rows[0];
};
