import { pool } from '../config/db.js';

async function addWelcomeEmailColumns() {
    try {
        console.log('🔧 Adding welcome email tracking columns to users table...\n');

        // Add columns
        await pool.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS welcome_email_sent BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS welcome_email_sent_at TIMESTAMP;
    `);
        console.log('✅ Columns added successfully');

        // Create index
        await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_users_welcome_email_sent 
      ON users(welcome_email_sent) 
      WHERE welcome_email_sent = FALSE;
    `);
        console.log('✅ Index created successfully');

        // Verify columns exist
        const result = await pool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      AND column_name LIKE 'welcome%'
      ORDER BY column_name;
    `);

        console.log('\n📊 Welcome email columns:');
        console.table(result.rows);

        console.log('\n✨ Migration complete! Welcome email system is ready.\n');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        process.exit(1);
    }
}

addWelcomeEmailColumns();
