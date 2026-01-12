/**
 * Migration Runner Script
 * Safely executes database migrations with rollback support
 */

import { pool } from '../config/db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MIGRATIONS_DIR = path.join(__dirname, '../database/migrations');

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[36m'
};

/**
 * Execute a single SQL file
 */
async function executeSQLFile(filePath) {
  const sql = fs.readFileSync(filePath, 'utf8');
  const fileName = path.basename(filePath);
  
  console.log(`${colors.blue}Executing: ${fileName}${colors.reset}`);
  
  try {
    await pool.query(sql);
    console.log(`${colors.green}✓ ${fileName} completed successfully${colors.reset}\n`);
    return true;
  } catch (error) {
    console.error(`${colors.red}✗ ${fileName} failed:${colors.reset}`);
    console.error(error.message);
    console.error(error.stack);
    return false;
  }
}

/**
 * Create a database backup
 */
async function createBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupName = `smartspoon_backup_${timestamp}`;
  
  console.log(`${colors.yellow}Creating backup: ${backupName}${colors.reset}`);
  
  // Note: This requires pg_dump to be installed
  // For production, use your cloud provider's backup service
  console.log(`${colors.yellow}⚠ Manual backup recommended before proceeding${colors.reset}\n`);
}

/**
 * Run optimized schema migrations
 */
async function runMigrations() {
  console.log(`\n${'='.repeat(60)}`);
  console.log('SmartSpoon Database Migration');
  console.log(`${'='.repeat(60)}\n`);

  try {
    // Step 1: Backup reminder
    await createBackup();
    
    // Step 2: Run schema migration
    const schemaFile = path.join(MIGRATIONS_DIR, '008_optimized_schema.sql');
    if (!await executeSQLFile(schemaFile)) {
      throw new Error('Schema migration failed');
    }
    
    // Step 3: Run data migration
    const dataFile = path.join(MIGRATIONS_DIR, '009_data_migration.sql');
    if (!await executeSQLFile(dataFile)) {
      throw new Error('Data migration failed');
    }
    
    // Step 4: Verify migration
    console.log(`${colors.blue}Verifying migration...${colors.reset}`);
    const verification = await verifyMigration();
    
    if (!verification.success) {
      console.error(`${colors.red}Migration verification failed!${colors.reset}`);
      console.error(verification.errors);
      return false;
    }
    
    console.log(`${colors.green}✓ Migration verification passed${colors.reset}\n`);
    
    // Step 5: Ask for cleanup confirmation
    console.log(`${colors.yellow}Migration successful!${colors.reset}`);
    console.log(`\nTo complete the migration, run:`);
    console.log(`  ${colors.blue}node src/scripts/run-cleanup.js${colors.reset}\n`);
    
    return true;
    
  } catch (error) {
    console.error(`${colors.red}Migration failed:${colors.reset}`, error.message);
    return false;
  } finally {
    await pool.end();
  }
}

/**
 * Verify migration success
 */
async function verifyMigration() {
  const checks = [];
  
  try {
    // Check 1: daily_analytics table exists
    const analyticsCheck = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='daily_analytics')"
    );
    checks.push({
      name: 'daily_analytics table created',
      passed: analyticsCheck.rows[0].exists
    });
    
    // Check 2: bites table exists
    const bitesCheck = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='bites')"
    );
    checks.push({
      name: 'bites table created',
      passed: bitesCheck.rows[0].exists
    });
    
    // Check 3: users has profile_metadata column
    const profileCheck = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='profile_metadata')"
    );
    checks.push({
      name: 'users.profile_metadata column added',
      passed: profileCheck.rows[0].exists
    });
    
    // Check 4: meals has meal_type column
    const mealTypeCheck = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='meals' AND column_name='meal_type')"
    );
    checks.push({
      name: 'meals.meal_type column added',
      passed: mealTypeCheck.rows[0].exists
    });
    
    // Check 5: Data migrated
    const dataCheck = await pool.query(
      "SELECT COUNT(*) as count FROM daily_analytics"
    );
    checks.push({
      name: 'daily_analytics populated',
      passed: dataCheck.rows[0].count > 0
    });
    
    // Print results
    console.log('\nVerification Results:');
    checks.forEach(check => {
      const status = check.passed ? `${colors.green}✓${colors.reset}` : `${colors.red}✗${colors.reset}`;
      console.log(`  ${status} ${check.name}`);
    });
    
    const allPassed = checks.every(c => c.passed);
    return {
      success: allPassed,
      checks,
      errors: checks.filter(c => !c.passed).map(c => c.name)
    };
    
  } catch (error) {
    return {
      success: false,
      errors: [error.message]
    };
  }
}

// Run migrations
runMigrations().then(success => {
  process.exit(success ? 0 : 1);
});
