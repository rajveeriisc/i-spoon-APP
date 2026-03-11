-- ============================================================================
-- 002_v3_optimized.sql
-- Optimized schema update: aligns backend with actual app features.
-- No duplicate tables, no unused columns.
-- ============================================================================

-- ============================================================================
-- 1. USERS — add phone, gender, location, age (profile fields)
-- ============================================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone       VARCHAR(30),
  ADD COLUMN IF NOT EXISTS gender      VARCHAR(20),
  ADD COLUMN IF NOT EXISTS location    VARCHAR(200),
  ADD COLUMN IF NOT EXISTS age         SMALLINT CHECK (age >= 0 AND age <= 150);


ALTER TABLE eating_sessions
  ADD COLUMN IF NOT EXISTS uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
  ADD COLUMN IF NOT EXISTS avg_pace_bpm REAL,
  ADD COLUMN IF NOT EXISTS tremor_index SMALLINT DEFAULT 0 CHECK (tremor_index >= 0 AND tremor_index <= 100);

-- Index for fast uuid lookup (used during sync)
CREATE INDEX IF NOT EXISTS idx_eating_sessions_uuid ON eating_sessions(uuid);

-- ============================================================================
-- 2. DAILY SUMMARIES — add tremor_index and total_eating_min
-- ============================================================================

ALTER TABLE daily_summaries
  ADD COLUMN IF NOT EXISTS avg_tremor_index SMALLINT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_eating_min DECIMAL(8,2) DEFAULT 0;

-- ============================================================================
-- 3. UPDATE DAILY SUMMARY TRIGGER to include new columns
-- ============================================================================

CREATE OR REPLACE FUNCTION update_daily_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_summaries (
        user_id, date,
        total_bites, total_eating_min, total_eating_duration_min,
        breakfast_bites, lunch_bites, dinner_bites, snack_bites,
        avg_tremor_index
    )
    SELECT
        user_id,
        DATE(started_at) AS date,
        SUM(total_bites)                                                        AS total_bites,
        SUM(duration_minutes)                                                   AS total_eating_min,
        SUM(duration_minutes)                                                   AS total_eating_duration_min,
        SUM(CASE WHEN meal_type = 'Breakfast' THEN total_bites ELSE 0 END)     AS breakfast_bites,
        SUM(CASE WHEN meal_type = 'Lunch'     THEN total_bites ELSE 0 END)     AS lunch_bites,
        SUM(CASE WHEN meal_type = 'Dinner'    THEN total_bites ELSE 0 END)     AS dinner_bites,
        SUM(CASE WHEN meal_type = 'Snack'     THEN total_bites ELSE 0 END)     AS snack_bites,
        COALESCE(AVG(tremor_index)::SMALLINT, 0)                               AS avg_tremor_index
    FROM eating_sessions
    WHERE user_id = NEW.user_id AND DATE(started_at) = DATE(NEW.started_at)
    GROUP BY user_id, DATE(started_at)
    ON CONFLICT (user_id, date) DO UPDATE SET
        total_bites              = EXCLUDED.total_bites,
        total_eating_min         = EXCLUDED.total_eating_min,
        total_eating_duration_min = EXCLUDED.total_eating_duration_min,
        breakfast_bites          = EXCLUDED.breakfast_bites,
        lunch_bites              = EXCLUDED.lunch_bites,
        dinner_bites             = EXCLUDED.dinner_bites,
        snack_bites              = EXCLUDED.snack_bites,
        avg_tremor_index         = EXCLUDED.avg_tremor_index,
        updated_at               = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_daily_summary ON eating_sessions;
CREATE TRIGGER trigger_update_daily_summary
    AFTER INSERT OR UPDATE ON eating_sessions
    FOR EACH ROW EXECUTE FUNCTION update_daily_summary();

-- ============================================================================
-- 4. DROP LEGACY TABLES (if they still exist from old migrations)
-- ============================================================================

DROP TABLE IF EXISTS tremor_metrics          CASCADE;
DROP TABLE IF EXISTS daily_tremor_breakdown  CASCADE;
DROP TABLE IF EXISTS daily_analytics         CASCADE;
DROP TABLE IF EXISTS notification_history    CASCADE;
DROP TABLE IF EXISTS notification_templates  CASCADE;
DROP TABLE IF EXISTS notification_throttle_log CASCADE;
DROP TABLE IF EXISTS user_notification_preferences CASCADE;
DROP TABLE IF EXISTS bites                   CASCADE;
DROP TABLE IF EXISTS temperature_logs        CASCADE;
DROP TABLE IF EXISTS device_sessions         CASCADE;
DROP TABLE IF EXISTS profile_metadata        CASCADE;
