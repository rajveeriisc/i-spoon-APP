import { pool } from '../config/db.js';

async function checkDatabase() {
    try {
        // Check if meals table exists
        const mealsCheck = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'meals'
      ORDER BY ordinal_position
    `);

        console.log('\n=== MEALS TABLE STRUCTURE ===');
        if (mealsCheck.rows.length === 0) {
            console.log('❌ meals table does not exist');
        } else {
            console.log('✅ meals table exists with columns:');
            mealsCheck.rows.forEach(row => {
                console.log(`  - ${row.column_name} (${row.data_type})`);
            });
        }

        // Check if bite_events exists
        const biteEventsCheck = await pool.query(`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'bite_events'
      )
    `);
        console.log('\n=== BITE_EVENTS TABLE ===');
        console.log(biteEventsCheck.rows[0].exists ? '✅ exists' : '❌ does not exist');

        // Check if bites exists
        const bitesCheck = await pool.query(`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'bites'
      )
    `);
        console.log('\n=== BITES TABLE ===');
        console.log(bitesCheck.rows[0].exists ? '✅ exists' : '❌ does not exist');

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await pool.end();
    }
}

checkDatabase();
