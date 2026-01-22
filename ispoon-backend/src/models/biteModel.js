import { pool } from "../config/db.js";

/**
 * Bite Model - Handles granular bite events with tremor data
 */

// Get bites for a specific meal
export const getBitesForMeal = async (mealId) => {
    const res = await pool.query(
        `SELECT 
      id, meal_id, timestamp, tremor_magnitude_rad_s, tremor_frequency_hz,
      is_valid, sequence_number, created_at
    FROM bites
    WHERE meal_id = $1
    ORDER BY sequence_number ASC`,
        [mealId]
    );

    return res.rows;
};

// Create a new bite event
export const createBite = async (biteData) => {
    const {
        meal_id,
        timestamp,
        tremor_magnitude_rad_s = null,
        tremor_frequency_hz = null,
        is_valid = true,
        sequence_number
    } = biteData;

    const res = await pool.query(
        `INSERT INTO bites (
      meal_id, timestamp, tremor_magnitude_rad_s, tremor_frequency_hz,
      is_valid, sequence_number
    ) VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING *`,
        [meal_id, timestamp, tremor_magnitude_rad_s, tremor_frequency_hz, is_valid, sequence_number]
    );

    return res.rows[0];
};

// Bulk insert bites (for efficient batch processing)
export const createBitesBatch = async (bites) => {
    if (bites.length === 0) return [];

    const values = [];
    const placeholders = [];

    bites.forEach((bite, index) => {
        const offset = index * 6;
        placeholders.push(
            `($${offset + 1}, $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6})`
        );
        values.push(
            bite.meal_id,
            bite.timestamp,
            bite.tremor_magnitude_rad_s || null,
            bite.tremor_frequency_hz || null,
            bite.is_valid !== undefined ? bite.is_valid : true,
            bite.sequence_number
        );
    });

    const query = `
    INSERT INTO bites (
      meal_id, timestamp, tremor_magnitude_rad_s, tremor_frequency_hz,
      is_valid, sequence_number
    ) VALUES ${placeholders.join(', ')}
    RETURNING *
  `;

    const res = await pool.query(query, values);
    return res.rows;
};

// Get tremor analysis for a meal
export const getTremorAnalysisForMeal = async (mealId) => {
    const res = await pool.query(
        `SELECT 
      AVG(tremor_magnitude_rad_s) as avg_magnitude,
      MAX(tremor_magnitude_rad_s) as max_magnitude,
      MIN(tremor_magnitude_rad_s) as min_magnitude,
      AVG(tremor_frequency_hz) as avg_frequency,
      COUNT(*) FILTER (WHERE tremor_magnitude_rad_s > 0.5) as high_tremor_count,
      COUNT(*) as total_bites
    FROM bites
    WHERE meal_id = $1 AND is_valid = true`,
        [mealId]
    );

    return res.rows[0];
};

// Get bite count for a meal
export const getBiteCount = async (mealId) => {
    const res = await pool.query(
        `SELECT COUNT(*) as count FROM bites WHERE meal_id = $1 AND is_valid = true`,
        [mealId]
    );

    return parseInt(res.rows[0].count);
};

// Delete bites for a meal (cascade will handle this, but explicit method for clarity)
export const deleteBitesForMeal = async (mealId) => {
    await pool.query('DELETE FROM bites WHERE meal_id = $1', [mealId]);
};
