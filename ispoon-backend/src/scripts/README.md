# Database Scripts

Scripts for managing database operations, seeding test data, and maintenance.

---

## 📜 Available Scripts

### 1. **seed_bites.js** - Seed Bite Data for Testing

Seeds realistic bite data for users. Highly configurable for different scales.

#### Basic Usage

```bash
# Default: Seeds ALL users with 90 days of data
node src/scripts/seed_bites.js
```

#### Configuration Options

Control the script via environment variables:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SEED_USER_LIMIT` | Number of users to seed | All users | `50` |
| `SEED_DAYS` | Days of historical data | `90` | `180` |
| `SEED_MIN_BITES` | Minimum bites per day | `30` | `50` |
| `SEED_MAX_BITES` | Maximum bites per day | `250` | `300` |

#### Usage Examples

**Development (small dataset):**
```bash
SEED_USER_LIMIT=10 SEED_DAYS=30 node src/scripts/seed_bites.js
```

**Staging (medium dataset):**
```bash
SEED_USER_LIMIT=100 SEED_DAYS=60 node src/scripts/seed_bites.js
```

**Production Testing (large dataset):**
```bash
SEED_USER_LIMIT=1000 SEED_DAYS=180 node src/scripts/seed_bites.js
```

**Seed ALL users with 1 year of data:**
```bash
SEED_DAYS=365 node src/scripts/seed_bites.js
```

#### Features

✅ **Realistic meal distribution** - Breakfast (7-10 AM), Lunch (12-2 PM), Dinner (6-9 PM)  
✅ **Natural variation** - Some days have 2 meals, some 3  
✅ **Bell curve distribution** - Most days around 100-150 bites, fewer extreme days  
✅ **Batch processing** - Handles large user bases efficiently  
✅ **Progress tracking** - Real-time progress updates  
✅ **Performance metrics** - Shows duration and bite counts  

#### Output Example

```
🌱 Starting bite data seeding...
📊 Configuration:
   - Days: 90
   - Bites per day: 30-250
   - User limit: all users
👥 Processing 1,250 users...
   Progress: 20% (250/1250 users)
   Progress: 40% (500/1250 users)
   Progress: 60% (750/1250 users)
   Progress: 80% (1000/1250 users)
   Progress: 100% (1250/1250 users)

✅ Seed complete!
   - Users processed: 1,250
   - Total bites inserted: 13,275,000
   - Average per user: 10,620
   - Duration: 45.32s
```

---

### 2. **cleanup.js** - Clean Expired Reset Tokens

Removes old password reset tokens from database.

#### Usage

```bash
node src/scripts/cleanup.js
```

#### Configuration

Set in `.env`:
```env
RESET_TOKEN_RETENTION=24h  # Clean tokens older than 24 hours
```

Supported units: `ms`, `s`, `m`, `h`, `d`

---

### 3. **migrate.js** - Run Database Migrations

Applies SQL migrations to database schema.

#### Usage

```bash
node src/scripts/migrate.js
```

---

## 🚀 NPM Scripts (Quick Commands)

Add these to your `package.json`:

```json
{
  "scripts": {
    "db:seed": "node src/scripts/seed_bites.js",
    "db:seed:dev": "SEED_USER_LIMIT=10 SEED_DAYS=30 node src/scripts/seed_bites.js",
    "db:seed:staging": "SEED_USER_LIMIT=100 SEED_DAYS=60 node src/scripts/seed_bites.js",
    "db:seed:large": "SEED_USER_LIMIT=1000 SEED_DAYS=180 node src/scripts/seed_bites.js",
    "db:cleanup": "node src/scripts/cleanup.js",
    "db:migrate": "node src/scripts/migrate.js"
  }
}
```

Then run:
```bash
npm run db:seed:dev       # Quick dev seeding
npm run db:seed:staging   # Medium dataset
npm run db:seed:large     # Large-scale testing
npm run db:cleanup        # Clean old tokens
npm run db:migrate        # Run migrations
```

---

## 📊 Performance Considerations

### Batch Processing
- Processes 10 users in parallel
- Prevents database overload
- Maintains consistent performance

### Data Volume Estimates

| Users | Days | Avg Bites/Day | Total Records | Est. Time |
|-------|------|---------------|---------------|-----------|
| 10 | 30 | 120 | 36,000 | ~2s |
| 100 | 60 | 120 | 720,000 | ~15s |
| 1,000 | 90 | 120 | 10,800,000 | ~2m |
| 10,000 | 180 | 120 | 216,000,000 | ~30m |

**Note:** Times are approximate and depend on database performance.

---

## 🔧 Best Practices

### Development
- Use small datasets (10-20 users, 30 days)
- Faster testing iterations
- Easy to debug

### Staging/QA
- Medium datasets (50-200 users, 60-90 days)
- Test performance under realistic load
- Validate analytics with sufficient data

### Production Load Testing
- Large datasets (1,000+ users, 180+ days)
- Stress test database queries
- Optimize indexes and queries

### Cleaning Up
Before re-seeding, truncate the bites table:
```sql
TRUNCATE TABLE bites CASCADE;
```

---

## 💡 Tips

1. **Start small** - Test with 10 users first
2. **Monitor database** - Watch CPU and memory during large seeds
3. **Use indexes** - Ensure `idx_bites_user_day` index exists
4. **Schedule cleanup** - Add `cleanup.js` to daily cron job
5. **Backup before seeding** - Always backup production data first

---

## 🐛 Troubleshooting

**Problem:** Script is too slow  
**Solution:** Reduce `SEED_USER_LIMIT` or `SEED_DAYS`, or increase `batchSize` in code

**Problem:** Out of memory  
**Solution:** Process fewer users at once, or restart script in batches

**Problem:** No users found  
**Solution:** Create users first using signup endpoints

**Problem:** Duplicate key errors  
**Solution:** The script uses `ON CONFLICT DO NOTHING`, this is normal and safe

---

## 📝 Example Workflows

### Fresh Development Setup
```bash
# 1. Run migrations
npm run db:migrate

# 2. Create test users (via API or SQL)
# INSERT INTO users (email, password, name) VALUES ...

# 3. Seed bite data for development
npm run db:seed:dev
```

### Weekly Cleanup (Cron Job)
```bash
# Add to crontab: Run every Sunday at 2 AM
0 2 * * 0 cd /path/to/ispoon-backend && npm run db:cleanup
```

### Performance Testing
```bash
# 1. Seed large dataset
npm run db:seed:large

# 2. Run analytics queries
# 3. Monitor query performance
# 4. Optimize indexes if needed
```

---

## 📞 Support

For issues or questions about these scripts, check:
- Database connection settings in `.env`
- PostgreSQL logs for errors
- Script output for detailed error messages

