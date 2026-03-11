import { pool } from "../config/db.js";

/**
 * Bite Model — bites table
 * Mirrors local SQLite bites table exactly.
 * Columns: id, meal_uuid, timestamp, sequence_number,
 *          tremor_magnitude, tremor_frequency, food_temp_c,
 *          is_valid, is_synced, created_at
 */

// ─── READ ─────────────────────────────────────────────────────────────────────

export const getBitesForMeal = async (mealUuid) => {
    const res = await pool.query(
        `SELECT id, meal_uuid, timestamp, sequence_number,
                tremor_magnitude, tremor_frequency, food_temp_c,
                is_valid, created_at
         FROM bites
         WHERE meal_uuid = $1
         ORDER BY timestamp ASC`,
        [mealUuid]
    );
    return res.rows;
};

// ─── WRITE ────────────────────────────────────────────────────────────────────

/**
 * Batch-upsert bites for a meal inside a single DB transaction.
 * All inserts succeed or the whole batch is rolled back — no partial sync.
 * Uses (meal_uuid, sequence_number) as conflict key so re-syncing is safe.
 *
 * @param {string} mealUuid
 * @param {Array}  bites
 * @returns {Array} rows that were actually inserted (skips conflicts)
 */
export const upsertBites = async (mealUuid, bites) => {
    if (!bites || bites.length === 0) return [];

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const inserted = [];
        for (const bite of bites) {
            const {
                timestamp,
                sequence_number  = null,
                tremor_magnitude = null,
                tremor_frequency = null,
                food_temp_c      = null,
                is_valid         = true,
            } = bite;

            const res = await client.query(
                `INSERT INTO bites
                     (meal_uuid, timestamp, sequence_number,
                      tremor_magnitude, tremor_frequency, food_temp_c, is_valid)
                 VALUES ($1, $2, $3, $4, $5, $6, $7)
                 ON CONFLICT DO NOTHING
                 RETURNING *`,
                [mealUuid, timestamp, sequence_number,
                 tremor_magnitude, tremor_frequency, food_temp_c, is_valid]
            );
            if (res.rows.length > 0) inserted.push(res.rows[0]);
        }

        await client.query('COMMIT');
        return inserted;
    } catch (err) {
        await client.query('ROLLBACK');
        throw err;
    } finally {
        client.release();
    }
};

export const deleteBitesForMeal = async (mealUuid) => {
    await pool.query('DELETE FROM bites WHERE meal_uuid = $1', [mealUuid]);
};
