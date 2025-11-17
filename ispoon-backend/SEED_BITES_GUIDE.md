# 🌱 Seed Bites Script - Quick Start Guide

## What Changed?

The `seed_bites.js` script has been updated for **large-scale production use**:

### Before ❌
- Fixed: Only 5 users
- Fixed: Only 14 days
- Not configurable
- No progress tracking
- Simple random distribution

### After ✅
- Dynamic: ALL users by default (configurable)
- Dynamic: 90 days by default (configurable)
- Fully configurable via environment variables
- Real-time progress tracking
- Realistic meal distribution (breakfast, lunch, dinner)
- Batch processing for better performance
- Detailed statistics and performance metrics

---

## 🚀 Quick Start

### 1️⃣ Install Dependencies

```bash
cd ispoon-backend
npm install
```

This will install `cross-env` for cross-platform environment variable support.

---

### 2️⃣ Run the Script

#### **For Development (Quick Test)**
Seeds 10 users with 30 days of data (~36,000 bites, takes ~2 seconds)

```bash
npm run seed:bites:dev
```

#### **For Staging/Testing**
Seeds 100 users with 60 days of data (~720,000 bites, takes ~15 seconds)

```bash
npm run seed:bites:staging
```

#### **For Large-Scale Testing**
Seeds 1,000 users with 180 days of data (~21 million bites, takes ~2 minutes)

```bash
npm run seed:bites:large
```

#### **For ALL Users**
Seeds all users in database with 90 days of data

```bash
npm run seed:bites
```

---

## ⚙️ Advanced Configuration

### Custom Settings

You can customize any parameter:

```bash
# Windows (PowerShell)
$env:SEED_USER_LIMIT=50; $env:SEED_DAYS=120; npm run seed:bites

# macOS/Linux
SEED_USER_LIMIT=50 SEED_DAYS=120 npm run seed:bites
```

### All Configuration Options

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `SEED_USER_LIMIT` | All users | Limit number of users | `50`, `100`, `1000` |
| `SEED_DAYS` | `90` | Days of historical data | `30`, `180`, `365` |
| `SEED_MIN_BITES` | `30` | Minimum bites per day | `20`, `50` |
| `SEED_MAX_BITES` | `250` | Maximum bites per day | `200`, `300` |

---

## 📊 What Data Is Generated?

### Realistic Patterns

✅ **Meal Times:**
- Breakfast: 7-10 AM (20-35% of daily bites)
- Lunch: 12-2 PM (30-45% of daily bites)
- Dinner: 6-9 PM (remaining bites)

✅ **Meal Frequency:**
- 70% of days: 3 meals
- 30% of days: 2 meals (skip breakfast)

✅ **Daily Variation:**
- Bell curve distribution (most days around 100-150 bites)
- 5% of days: No data (user didn't use spoon)

✅ **Bite Timing:**
- Bites spread throughout each meal (10-second intervals)
- Natural eating pace simulation

### Example Output

```
🌱 Starting bite data seeding...
📊 Configuration:
   - Days: 90
   - Bites per day: 30-250
   - User limit: 100 users
👥 Processing 100 users...
   Progress: 20% (20/100 users)
   Progress: 40% (40/100 users)
   Progress: 60% (60/100 users)
   Progress: 80% (80/100 users)
   Progress: 100% (100/100 users)

✅ Seed complete!
   - Users processed: 100
   - Total bites inserted: 1,062,000
   - Average per user: 10,620
   - Duration: 12.45s
```

---

## 🎯 Use Cases by Scale

### Development (Local Machine)
```bash
npm run seed:bites:dev
```
- **Users:** 10
- **Days:** 30
- **Records:** ~36,000
- **Time:** ~2 seconds
- **Use for:** Quick testing, UI development

### Staging/QA Environment
```bash
npm run seed:bites:staging
```
- **Users:** 100
- **Days:** 60
- **Records:** ~720,000
- **Time:** ~15 seconds
- **Use for:** Integration testing, performance validation

### Pre-Production Testing
```bash
npm run seed:bites:large
```
- **Users:** 1,000
- **Days:** 180
- **Records:** ~21 million
- **Time:** ~2 minutes
- **Use for:** Load testing, query optimization

### Production-Like Data
```bash
# Seed all users with 1 year of data
SEED_DAYS=365 npm run seed:bites
```
- **Users:** All in database
- **Days:** 365
- **Records:** Depends on user count
- **Use for:** Demo, investor presentations, realistic testing

---

## 💡 Pro Tips

### 1. Check User Count First
```sql
SELECT COUNT(*) FROM users;
```

### 2. Clear Existing Data (Optional)
```sql
TRUNCATE TABLE bites CASCADE;
```

### 3. Monitor Database During Large Seeds
```sql
-- Check table size
SELECT pg_size_pretty(pg_total_relation_size('bites'));

-- Check row count
SELECT COUNT(*) FROM bites;
```

### 4. Verify Data Distribution
```sql
-- Bites per user
SELECT user_id, COUNT(*) as bites
FROM bites
GROUP BY user_id
ORDER BY bites DESC
LIMIT 10;

-- Bites per day
SELECT DATE(occurred_at) as day, COUNT(*) as bites
FROM bites
GROUP BY day
ORDER BY day DESC
LIMIT 7;
```

---

## 🔧 Troubleshooting

### "No users found in database"
**Solution:** Create users first:
```bash
# Use signup API or insert directly
curl -X POST http://localhost:5000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#","name":"Test User"}'
```

### Script is taking too long
**Solution:** Reduce scope:
```bash
SEED_USER_LIMIT=10 SEED_DAYS=30 npm run seed:bites
```

### Database connection error
**Solution:** Check `.env` file:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/ispoon
```

---

## 📈 Performance Expectations

| Users | Days | Total Bites | Estimated Time |
|-------|------|-------------|----------------|
| 10 | 30 | ~36,000 | 2s |
| 50 | 60 | ~360,000 | 8s |
| 100 | 90 | ~1,080,000 | 15s |
| 500 | 90 | ~5,400,000 | 1m |
| 1,000 | 180 | ~21,600,000 | 2m |
| 10,000 | 90 | ~108,000,000 | 20m |

*Times are approximate and depend on database performance*

---

## 🎉 You're Ready!

Your seed script is now production-ready and can handle:
- ✅ Small development datasets
- ✅ Medium staging datasets  
- ✅ Large production-scale datasets
- ✅ Custom configurations for any scenario

Start with the dev preset and scale up as needed!

```bash
npm run seed:bites:dev
```

---

## 📚 Additional Resources

- **Full Documentation:** `src/scripts/README.md`
- **Script Code:** `src/scripts/seed_bites.js`
- **Database Schema:** `src/migrations/001_init.sql`

