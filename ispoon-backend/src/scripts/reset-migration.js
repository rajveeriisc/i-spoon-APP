import { pool } from '../config/db.js';

async function resetPartialMigration() {
    console.log('Resetting partial migration...\n');

    try {
        // Drop tables that might have been created in partial migration
        await pool.query('DROP TABLE IF EXISTS bites CASCADE');
        console.log('✓ Dropped bites table');

        await pool.query('DROP TABLE IF EXISTS temperature_logs CASCADE');
        console.log('✓ Dropped temperature_logs table');

        await pool.query('DROP TABLE IF EXISTS daily_analytics CASCADE');
        console.log('✓ Dropped daily_analytics table');

        await pool.query('DROP TABLE IF EXISTS devices_new CASCADE');
        console.log('✓ Dropped devices_new table');

        // Drop triggers
        await pool.query('DROP TRIGGER IF EXISTS trigger_update_daily_analytics ON meals');
        console.log('✓ Dropped trigger');

        // Drop functions
        await pool.query('DROP FUNCTION IF EXISTS update_daily_analytics() CASCADE');
        await pool.query('DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE');
        console.log('✓ Dropped functions');

        // Remove added columns from meals (optional - keep for now)
        // await pool.query('ALTER TABLE meals DROP COLUMN IF EXISTS meal_type CASCADE');
        // await pool.query('ALTER TABLE meals DROP COLUMN IF EXISTS device_id CASCADE');

        console.log('\n✅ Partial migration reset complete');
        console.log('You can now run: node src/scripts/run-migrations.js\n');

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await pool.end();
    }
}

resetPartialMigration();
