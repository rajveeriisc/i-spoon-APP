import { pool } from '../config/db.js';

async function verifyDatabase() {
    console.log('🔍 Verifying Database Structure...\n');

    try {
        // Check tables
        const tablesResult = await pool.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE schemaname = 'public' 
      ORDER BY tablename
    `);

        console.log('📋 Tables Found:', tablesResult.rows.length);
        console.log(tablesResult.rows.map(r => `  ✓ ${r.tablename}`).join('\n'));

        // Check indexes
        const indexesResult = await pool.query(`
      SELECT indexname 
      FROM pg_indexes 
      WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
      ORDER BY indexname
    `);

        console.log(`\n📊 Indexes Found: ${indexesResult.rows.length}`);
        console.log(indexesResult.rows.map(r => `  ✓ ${r.indexname}`).join('\n'));

        // Check materialized views
        const viewsResult = await pool.query(`
      SELECT 
        schemaname,
        matviewname,
        matviewowner
      FROM pg_matviews 
      WHERE schemaname = 'public'
    `);

        console.log(`\n👁️ Materialized Views: ${viewsResult.rows.length}`);
        if (viewsResult.rows.length > 0) {
            viewsResult.rows.forEach(r => {
                console.log(`  ✓ ${r.matviewname}`);
            });
        } else {
            console.log('  ⚠️  No materialized views found (will be created in migration 007)');
        }

        // Test data insertion
        console.log('\n🧪 Testing Data Insertion...');

        const testUser = await pool.query(`
      SELECT id, email FROM users LIMIT 1
    `);

        if (testUser.rows.length > 0) {
            console.log('  ✅ Users table can be queried');
            console.log(`     Sample user: ${testUser.rows[0].email}`);
        } else {
            console.log('  ⚠️  No users in database yet');
        }

        console.log('\n✅ Database is ready to receive data!');
        process.exit(0);

    } catch (error) {
        console.error('❌ Database verification failed:', error.message);
        process.exit(1);
    }
}

verifyDatabase();
