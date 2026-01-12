import { pool } from '../config/db.js';

async function checkAndPopulateAnalytics() {
    try {
        // Check if there are any meals
        const mealsCount = await pool.query('SELECT COUNT(*) FROM meals');
        console.log(`\nFound ${mealsCount.rows[0].count} meals in database`);

        if (parseInt(mealsCount.rows[0].count) === 0) {
            console.log('✓ No meals to migrate - daily_analytics will be populated when meals are added\n');
            return;
        }

        // Manually populate daily_analytics from existing meals
        console.log('Populating daily_analytics from existing meals...\n');

        await pool.query(`
      INSERT INTO daily_analytics (
        user_id,
        date,
        total_bites,
        avg_tremor_magnitude,
        max_tremor_magnitude,
        meal_breakdown,
        total_eating_duration_min
      )
      SELECT 
        m.user_id,
        DATE(m.started_at) as date,
        SUM(m.total_bites) as total_bites,
        AVG(m.tremor_index) as avg_tremor_magnitude,
        MAX(m.tremor_index) as max_tremor_magnitude,
        jsonb_object_agg(
          COALESCE(m.meal_type, 'Unknown'),
          m.total_bites
        ) as meal_breakdown,
        SUM(EXTRACT(EPOCH FROM (COALESCE(m.ended_at, m.started_at) - m.started_at)) / 60.0) as total_eating_duration_min
      FROM meals m
      WHERE m.started_at IS NOT NULL
      GROUP BY m.user_id, DATE(m.started_at)
      ON CONFLICT (user_id, date) DO UPDATE SET
        total_bites = EXCLUDED.total_bites,
        avg_tremor_magnitude = EXCLUDED.avg_tremor_magnitude,
        max_tremor_magnitude = EXCLUDED.max_tremor_magnitude,
        meal_breakdown = EXCLUDED.meal_breakdown,
        total_eating_duration_min = EXCLUDED.total_eating_duration_min,
        updated_at = NOW()
    `);

        const analyticsCount = await pool.query('SELECT COUNT(*) FROM daily_analytics');
        console.log(`✓ Populated ${analyticsCount.rows[0].count} rows in daily_analytics\n`);

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await pool.end();
    }
}

checkAndPopulateAnalytics();
