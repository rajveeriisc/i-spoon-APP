/**
 * Cleanup Script - Run ONLY after verifying migration success
 */

import { pool } from '../config/db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m'
};

async function runCleanup() {
    console.log(`${colors.yellow}⚠ WARNING: This will delete old tables${colors.reset}`);
    console.log('Make sure you have verified the migration was successful!\n');

    try {
        const cleanupFile = path.join(__dirname, '../database/migrations/010_cleanup_old_tables.sql');
        const sql = fs.readFileSync(cleanupFile, 'utf8');

        await pool.query(sql);

        console.log(`${colors.green}✓ Cleanup completed successfully${colors.reset}`);
        console.log('Old tables have been removed.\n');

    } catch (error) {
        console.error(`${colors.red}Cleanup failed:${colors.reset}`, error.message);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

runCleanup();
