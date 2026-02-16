import { pool } from './src/config/db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationFile = path.join(__dirname, 'src/migrations/007_add_heater_settings.sql');

console.log('🔄 Running migration: 007_add_heater_settings.sql');

try {
    const sql = fs.readFileSync(migrationFile, 'utf8');
    await pool.query(sql);
    console.log('✅ Migration completed successfully!');

    // Verify
    const res = await pool.query(`
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'user_devices' AND column_name LIKE 'heater_%'
  `);
    console.log('🔍 Verified Columns:', res.rows.map(r => r.column_name));

    await pool.end();
    process.exit(0);
} catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
}
