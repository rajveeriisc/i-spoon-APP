import { pool } from "../config/db.js";

/**
 * Meal Model - Handles eating sessions
 */

// Get meals for a user with pagination
export const getUserMeals = async (userId, { limit = 20, offset = 0, mealType = null } = {}) => {
    let query = `
    SELECT 
      id, user_id, device_id, started_at, ended_at, meal_type,
      total_bites, avg_pace_bpm, tremor_index, duration_minutes,
      avg_food_temp_c,
      created_at, updated_at
    FROM meals
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

// Get a single meal by ID
export const getMealById = async (mealId) => {
    const res = await pool.query(
        `SELECT * FROM meals WHERE id = $1`,
        [mealId]
    );
    return res.rows[0];
};

// Create a new meal
export const createMeal = async (mealData) => {
    const {
        user_id,
        device_id = null,
        started_at,
        ended_at = null,
        meal_type,
        total_bites = 0,
        avg_pace_bpm = null,
        tremor_index = null,
        duration_minutes = null,
        avg_food_temp_c = null,
        max_food_temp_c = null,
        min_food_temp_c = null
    } = mealData;

    const res = await pool.query(
        `INSERT INTO meals (
      user_id, device_id, started_at, ended_at, meal_type,
      total_bites, avg_pace_bpm, tremor_index, duration_minutes,
      avg_food_temp_c, max_food_temp_c, min_food_temp_c
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    RETURNING *`,
        [
            user_id, device_id, started_at, ended_at, meal_type,
            total_bites, avg_pace_bpm, tremor_index, duration_minutes,
            avg_food_temp_c, max_food_temp_c, min_food_temp_c
        ]
    );

    return res.rows[0];
};

// Update a meal
export const updateMeal = async (mealId, updates) => {
    const allowed = [
        'ended_at', 'meal_type', 'total_bites', 'avg_pace_bpm',
        'tremor_index', 'duration_minutes',
        'avg_food_temp_c', 'max_food_temp_c', 'min_food_temp_c'
    ];

    const setClauses = [];
    const values = [];

    for (const key of allowed) {
        if (Object.prototype.hasOwnProperty.call(updates, key)) {
            setClauses.push(`${key} = $${values.length + 1}`);
            values.push(updates[key]);
        }
    }

    if (setClauses.length === 0) {
        return getMealById(mealId);
    }

    setClauses.push('updated_at = NOW()');
    values.push(mealId);

    const query = `
    UPDATE meals 
    SET ${setClauses.join(', ')}
    WHERE id = $${values.length}
    RETURNING *
  `;

    const res = await pool.query(query, values);
    return res.rows[0];
};

// Delete a meal
export const deleteMeal = async (mealId) => {
    await pool.query('DELETE FROM meals WHERE id = $1', [mealId]);
};

// Get meal statistics for a user
export const getMealStats = async (userId, startDate, endDate) => {
    const res = await pool.query(
        `SELECT 
      COUNT(*) as total_meals,
      SUM(total_bites) as total_bites,
      AVG(avg_pace_bpm) as avg_pace,
      AVG(tremor_index) as avg_tremor,
      meal_type,
      COUNT(*) FILTER (WHERE meal_type = 'Breakfast') as breakfast_count,
      COUNT(*) FILTER (WHERE meal_type = 'Lunch') as lunch_count,
      COUNT(*) FILTER (WHERE meal_type = 'Dinner') as dinner_count,
      COUNT(*) FILTER (WHERE meal_type = 'Snack') as snack_count
    FROM meals
    WHERE user_id = $1
      AND started_at >= $2
      AND started_at <= $3
    GROUP BY meal_type`,
        [userId, startDate, endDate]
    );

    return res.rows;
};
