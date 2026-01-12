import { pool } from "../config/db.js";

/**
 * Temperature Model - Handles temperature logs during meals
 */

// Get temperature logs for a meal
export const getTemperatureLogsForMeal = async (mealId) => {
    const res = await pool.query(
        `SELECT 
      id, meal_id, timestamp, food_temp_c, ambient_temp_c, created_at
    FROM temperature_logs
    WHERE meal_id = $1
    ORDER BY timestamp ASC`,
        [mealId]
    );

    return res.rows;
};

// Create a temperature log entry
export const createTemperatureLog = async (logData) => {
    const {
        meal_id,
        timestamp,
        food_temp_c = null,
        ambient_temp_c = null
    } = logData;

    const res = await pool.query(
        `INSERT INTO temperature_logs (
      meal_id, timestamp, food_temp_c, ambient_temp_c
    ) VALUES ($1, $2, $3, $4)
    RETURNING *`,
        [meal_id, timestamp, food_temp_c, ambient_temp_c]
    );

    return res.rows[0];
};

// Bulk insert temperature logs
export const createTemperatureLogsBatch = async (logs) => {
    if (logs.length === 0) return [];

    const values = [];
    const placeholders = [];

    logs.forEach((log, index) => {
        const offset = index * 4;
        placeholders.push(
            `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4})`
        );
        values.push(
            log.meal_id,
            log.timestamp,
            log.food_temp_c || null,
            log.ambient_temp_c || null
        );
    });

    const query = `
    INSERT INTO temperature_logs (
      meal_id, timestamp, food_temp_c, ambient_temp_c
    ) VALUES ${placeholders.join(', ')}
    RETURNING *
  `;

    const res = await pool.query(query, values);
    return res.rows;
};

// Get temperature statistics for a meal
export const getTemperatureStatsForMeal = async (mealId) => {
    const res = await pool.query(
        `SELECT 
      AVG(food_temp_c) as avg_food_temp,
      MAX(food_temp_c) as max_food_temp,
      MIN(food_temp_c) as min_food_temp,
      AVG(ambient_temp_c) as avg_ambient_temp
    FROM temperature_logs
    WHERE meal_id = $1`,
        [mealId]
    );

    return res.rows[0];
};

// Delete temperature logs for a meal
export const deleteTemperatureLogsForMeal = async (mealId) => {
    await pool.query('DELETE FROM temperature_logs WHERE meal_id = $1', [mealId]);
};
