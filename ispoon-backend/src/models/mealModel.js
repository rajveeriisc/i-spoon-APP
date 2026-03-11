import { pool } from "../config/db.js";

/**
 * Meal Model — eating_sessions table (V3 optimized schema)
 * Columns: id, uuid, user_id, device_id, started_at, ended_at, meal_type,
 *          total_bites, avg_pace_bpm, tremor_index, duration_minutes,
 *          avg_food_temp_c, created_at, updated_at
 */

// ─── READ ─────────────────────────────────────────────────────────────────────

export const getUserMeals = async (userId, { limit = 20, offset = 0, mealType = null } = {}) => {
    // Clamp to prevent DoS via unlimited DB reads
    limit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);
    offset = Math.max(parseInt(offset, 10) || 0, 0);
    let query = `
        SELECT id, uuid, user_id, device_id, started_at, ended_at, meal_type,
               total_bites, avg_pace_bpm, tremor_index,
               duration_minutes, avg_food_temp_c, created_at, updated_at
        FROM eating_sessions
        WHERE user_id = $1
    `;
    const params = [userId];

    if (mealType) {
        query += ` AND meal_type = $${params.length + 1}`;
        params.push(mealType);
    }

    query += ` ORDER BY started_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(limit, offset);

    const res = await pool.query(query, params);
    return res.rows;
};

export const getMealById = async (mealId) => {
    const res = await pool.query(
        `SELECT id, uuid, user_id, device_id, started_at, ended_at, meal_type,
                total_bites, avg_pace_bpm, tremor_index,
                duration_minutes, avg_food_temp_c, created_at, updated_at
         FROM eating_sessions WHERE id = $1`,
        [mealId]
    );
    return res.rows[0];
};

export const getMealByUuid = async (uuid) => {
    const res = await pool.query(
        `SELECT id, uuid, user_id, device_id, started_at, ended_at, meal_type,
                total_bites, avg_pace_bpm, tremor_index,
                duration_minutes, avg_food_temp_c, created_at, updated_at
         FROM eating_sessions WHERE uuid = $1`,
        [uuid]
    );
    return res.rows[0];
};

// ─── WRITE ────────────────────────────────────────────────────────────────────

export const createMeal = async (mealData) => {
    const {
        uuid = null,
        user_id,
        device_id = null,
        started_at,
        ended_at = null,
        meal_type,
        total_bites = 0,
        avg_pace_bpm = null,
        tremor_index = 0,
        duration_minutes = null,
        avg_food_temp_c = null,
    } = mealData;

    const res = await pool.query(
        `INSERT INTO eating_sessions
             (uuid, user_id, device_id, started_at, ended_at, meal_type,
              total_bites, avg_pace_bpm, tremor_index, duration_minutes, avg_food_temp_c)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         RETURNING *`,
        [uuid, user_id, device_id, started_at, ended_at, meal_type,
            total_bites, avg_pace_bpm, tremor_index, duration_minutes, avg_food_temp_c]
    );
    return res.rows[0];
};

export const updateMeal = async (mealId, updates) => {
    const allowed = [
        'ended_at', 'meal_type', 'total_bites', 'avg_pace_bpm',
        'tremor_index', 'duration_minutes', 'avg_food_temp_c',
    ];

    const setClauses = [];
    const values = [];

    for (const key of allowed) {
        if (Object.prototype.hasOwnProperty.call(updates, key)) {
            setClauses.push(`${key} = $${values.length + 1}`);
            values.push(updates[key]);
        }
    }

    if (setClauses.length === 0) return getMealById(mealId);

    setClauses.push('updated_at = NOW()');
    values.push(mealId);

    const res = await pool.query(
        `UPDATE eating_sessions SET ${setClauses.join(', ')}
         WHERE id = $${values.length} RETURNING *`,
        values
    );
    return res.rows[0];
};

// Upsert by uuid — used during mobile sync
export const upsertMealByUuid = async (mealData) => {
    const {
        uuid,
        user_id,
        device_id = null,
        started_at,
        ended_at = null,
        meal_type,
        total_bites = 0,
        avg_pace_bpm = null,
        tremor_index = 0,
        duration_minutes = null,
        avg_food_temp_c = null,
    } = mealData;

    const res = await pool.query(
        `INSERT INTO eating_sessions
             (uuid, user_id, device_id, started_at, ended_at, meal_type,
              total_bites, avg_pace_bpm, tremor_index, duration_minutes, avg_food_temp_c)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
         ON CONFLICT (uuid) DO UPDATE SET
             ended_at         = EXCLUDED.ended_at,
             meal_type        = EXCLUDED.meal_type,
             total_bites      = EXCLUDED.total_bites,
             avg_pace_bpm     = EXCLUDED.avg_pace_bpm,
             tremor_index     = EXCLUDED.tremor_index,
             duration_minutes = EXCLUDED.duration_minutes,
             avg_food_temp_c  = EXCLUDED.avg_food_temp_c,
             updated_at       = NOW()
         RETURNING *`,
        [uuid, user_id, device_id, started_at, ended_at, meal_type,
            total_bites, avg_pace_bpm, tremor_index, duration_minutes, avg_food_temp_c]
    );
    return res.rows[0];
};

export const deleteMeal = async (mealId) => {
    await pool.query('DELETE FROM eating_sessions WHERE id = $1', [mealId]);
};

// ─── ANALYTICS ───────────────────────────────────────────────────────────────

export const getMealStats = async (userId, startDate, endDate) => {
    const res = await pool.query(
        `SELECT
             COUNT(*)                                                                AS total_meals,
             COALESCE(SUM(total_bites), 0)                                          AS total_bites,
             COALESCE(ROUND(AVG(duration_minutes)::NUMERIC, 1), 0)                 AS avg_duration_min,
             COALESCE(ROUND(AVG(avg_pace_bpm)::NUMERIC, 1), 0)                    AS avg_pace_bpm,
             COALESCE(ROUND(AVG(tremor_index)::NUMERIC, 0), 0)                    AS avg_tremor_index,
             COUNT(*) FILTER (WHERE meal_type = 'Breakfast')                       AS breakfast_count,
             COUNT(*) FILTER (WHERE meal_type = 'Lunch')                           AS lunch_count,
             COUNT(*) FILTER (WHERE meal_type = 'Dinner')                          AS dinner_count,
             COUNT(*) FILTER (WHERE meal_type IN ('Snack','Snacks'))                AS snack_count
         FROM eating_sessions
         WHERE user_id = $1 AND started_at >= $2 AND started_at <= $3`,
        [userId, startDate, endDate]
    );
    return res.rows[0];
};
