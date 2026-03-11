/**
 * Analytics Model — reads from the aligned schema (003_align_local_schema.sql)
 *
 * Tables used:
 *   daily_summaries   — per-day aggregates (fully aligned with local SQLite)
 *   eating_sessions   — per-meal records
 *   bites             — per-bite tremor + temperature readings
 */

import { pool } from "../config/db.js";

// ---------------------------------------------------------------------------
// getDailyAnalytics: return one row per day in [start, end] range
// ---------------------------------------------------------------------------
export const getDailyAnalytics = async (userId, start, end) => {
    const res = await pool.query(
        `SELECT
            date,
            total_bites,
            total_eating_min,
            breakfast_bites,
            lunch_bites,
            dinner_bites,
            snack_bites,
            avg_tremor_index,
            avg_tremor_magnitude,
            avg_tremor_frequency,
            tremor_low_count,
            tremor_moderate_count,
            tremor_high_count,
            avg_food_temp_c,
            updated_at
         FROM daily_summaries
         WHERE user_id = $1
           AND date BETWEEN $2 AND $3
         ORDER BY date ASC`,
        [userId, start, end]
    );
    return res.rows;
};

// ---------------------------------------------------------------------------
// getAnalyticsForDate: single day snapshot
// ---------------------------------------------------------------------------
export const getAnalyticsForDate = async (userId, date) => {
    const res = await pool.query(
        `SELECT
            date,
            total_bites,
            total_eating_min,
            breakfast_bites,
            lunch_bites,
            dinner_bites,
            snack_bites,
            avg_tremor_index
         FROM daily_summaries
         WHERE user_id = $1 AND date = $2`,
        [userId, date]
    );
    if (res.rows.length === 0) return null;
    const row = res.rows[0];
    return {
        ...row,
        meal_breakdown: {
            Breakfast: row.breakfast_bites ?? 0,
            Lunch: row.lunch_bites ?? 0,
            Dinner: row.dinner_bites ?? 0,
            Snack: row.snack_bites ?? 0,
        },
    };
};

// ---------------------------------------------------------------------------
// getAnalyticsSummary: aggregated totals over a date range
// ---------------------------------------------------------------------------
export const getAnalyticsSummary = async (userId, start, end) => {
    // Summary from daily_summaries
    const summaryRes = await pool.query(
        `SELECT
            COUNT(*)::int                         AS days_tracked,
            SUM(total_bites)::int                 AS total_bites,
            ROUND(AVG(total_bites)::numeric, 1)   AS avg_daily_bites,
            SUM(total_eating_min)                 AS total_eating_min,
            ROUND(AVG(total_eating_min)::numeric, 1) AS avg_eating_min_per_day,
            ROUND(AVG(avg_tremor_index)::numeric, 1) AS avg_tremor_index,
            SUM(breakfast_bites)::int             AS breakfast_bites,
            SUM(lunch_bites)::int                 AS lunch_bites,
            SUM(dinner_bites)::int                AS dinner_bites,
            SUM(snack_bites)::int                 AS snack_bites
         FROM daily_summaries
         WHERE user_id = $1
           AND date BETWEEN $2 AND $3`,
        [userId, start, end]
    );

    // Number of meal sessions in the same period
    const sessionRes = await pool.query(
        `SELECT COUNT(*)::int AS total_sessions,
                ROUND(AVG(avg_pace_bpm)::numeric, 2) AS avg_pace_bpm
         FROM eating_sessions
         WHERE user_id = $1
           AND DATE(started_at) BETWEEN $2 AND $3`,
        [userId, start, end]
    );

    return {
        ...summaryRes.rows[0],
        ...sessionRes.rows[0],
    };
};
