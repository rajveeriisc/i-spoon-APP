import { pool } from '../config/db.js';

async function checkUsersTable() {
    try {
        const result = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'users'
      ORDER BY ordinal_position
    `);

        console.log('\n=== USERS TABLE COLUMNS ===');
        result.rows.forEach(row => {
            console.log(`${row.column_name} (${row.data_type}) ${row.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`);
        });

    } catch (error) {
        console.error('Error:', error.message);
    } finally {
        await pool.end();
    }
}

checkUsersTable();
