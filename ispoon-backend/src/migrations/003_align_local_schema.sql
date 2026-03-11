-- ============================================================================
-- 003_align_local_schema.sql
-- Aligns backend PostgreSQL schema with local SQLite so data is identical
-- on both sides and sync issues are eliminated.
--
-- Changes:
--   1. Add bites table (mirrors local SQLite bites table exactly)
--   2. Add missing columns to daily_summaries
--   3. Update daily_summaries trigger to compute all columns from bites
-- ============================================================================

-- ============================================================================
-- 1. BITES TABLE (mirrors local SQLite bites table)
-- ============================================================================

CREATE TABLE IF NOT EXISTS bites (
    id               BIGSERIAL PRIMARY KEY,
    meal_uuid        UUID        NOT NULL REFERENCES eating_sessions(uuid) ON DELETE CASCADE,
    timestamp        TIMESTAMPTZ NOT NULL,
    sequence_number  INTEGER,
    tremor_magnitude REAL,
    tremor_frequency REAL,
    food_temp_c      REAL,
    is_valid         BOOLEAN     DEFAULT TRUE,
    is_synced        BOOLEAN     DEFAULT TRUE,  -- always true on backend
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bites_meal_uuid  ON bites(meal_uuid);
CREATE INDEX IF NOT EXISTS idx_bites_timestamp  ON bites(timestamp DESC);

-- ============================================================================
-- 2. ALIGN daily_summaries — add columns that exist locally but not on backend
-- ============================================================================

ALTER TABLE daily_summaries
    ADD COLUMN IF NOT EXISTS avg_tremor_magnitude REAL    DEFAULT 0,
    ADD COLUMN IF NOT EXISTS avg_tremor_frequency REAL    DEFAULT 0,
    ADD COLUMN IF NOT EXISTS tremor_low_count     INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS tremor_moderate_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS tremor_high_count    INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS avg_food_temp_c      REAL    DEFAULT 0;

-- ============================================================================
-- 3. UPDATE daily_summaries TRIGGER
--    Now joins bites for granular tremor + temperature data,
--    exactly matching local SQLite rebuildDailySummary() query.
-- ============================================================================

CREATE OR REPLACE FUNCTION update_daily_summary()
RETURNS TRIGGER AS $$
DECLARE
    v_date DATE;
    v_user BIGINT;
BEGIN
    v_date := DATE(NEW.started_at);
    v_user := NEW.user_id;

    INSERT INTO daily_summaries (
        user_id, date,
        total_bites,
        total_eating_min, total_eating_duration_min,
        breakfast_bites, lunch_bites, dinner_bites, snack_bites,
        avg_tremor_index,
        avg_tremor_magnitude, avg_tremor_frequency,
        tremor_low_count, tremor_moderate_count, tremor_high_count,
        avg_food_temp_c
    )
    SELECT
        es.user_id,
        DATE(es.started_at)                                                              AS date,
        SUM(es.total_bites)                                                              AS total_bites,
        SUM(es.duration_minutes)                                                         AS total_eating_min,
        SUM(es.duration_minutes)                                                         AS total_eating_duration_min,
        SUM(CASE WHEN es.meal_type = 'Breakfast' THEN es.total_bites ELSE 0 END)        AS breakfast_bites,
        SUM(CASE WHEN es.meal_type = 'Lunch'     THEN es.total_bites ELSE 0 END)        AS lunch_bites,
        SUM(CASE WHEN es.meal_type = 'Dinner'    THEN es.total_bites ELSE 0 END)        AS dinner_bites,
        SUM(CASE WHEN es.meal_type = 'Snack'     THEN es.total_bites ELSE 0 END)        AS snack_bites,
        COALESCE(AVG(es.tremor_index)::SMALLINT, 0)                                     AS avg_tremor_index,
        COALESCE(AVG(b.tremor_magnitude), 0)                                             AS avg_tremor_magnitude,
        COALESCE(AVG(b.tremor_frequency), 0)                                             AS avg_tremor_frequency,
        COUNT(CASE WHEN b.tremor_magnitude < 0.6                              THEN 1 END) AS tremor_low_count,
        COUNT(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 END) AS tremor_moderate_count,
        COUNT(CASE WHEN b.tremor_magnitude >= 1.4                             THEN 1 END) AS tremor_high_count,
        COALESCE(AVG(b.food_temp_c), 0)                                                  AS avg_food_temp_c
    FROM eating_sessions es
    LEFT JOIN bites b ON b.meal_uuid = es.uuid AND b.is_valid = TRUE
    WHERE es.user_id = v_user AND DATE(es.started_at) = v_date
    GROUP BY es.user_id, DATE(es.started_at)
    ON CONFLICT (user_id, date) DO UPDATE SET
        total_bites               = EXCLUDED.total_bites,
        total_eating_min          = EXCLUDED.total_eating_min,
        total_eating_duration_min = EXCLUDED.total_eating_duration_min,
        breakfast_bites           = EXCLUDED.breakfast_bites,
        lunch_bites               = EXCLUDED.lunch_bites,
        dinner_bites              = EXCLUDED.dinner_bites,
        snack_bites               = EXCLUDED.snack_bites,
        avg_tremor_index          = EXCLUDED.avg_tremor_index,
        avg_tremor_magnitude      = EXCLUDED.avg_tremor_magnitude,
        avg_tremor_frequency      = EXCLUDED.avg_tremor_frequency,
        tremor_low_count          = EXCLUDED.tremor_low_count,
        tremor_moderate_count     = EXCLUDED.tremor_moderate_count,
        tremor_high_count         = EXCLUDED.tremor_high_count,
        avg_food_temp_c           = EXCLUDED.avg_food_temp_c,
        updated_at                = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger on both eating_sessions (meal changes) AND bites (new bite data)
DROP TRIGGER IF EXISTS trigger_update_daily_summary ON eating_sessions;
CREATE TRIGGER trigger_update_daily_summary
    AFTER INSERT OR UPDATE ON eating_sessions
    FOR EACH ROW EXECUTE FUNCTION update_daily_summary();

-- Also re-aggregate when bites are inserted (so tremor+temp fields update immediately)
CREATE OR REPLACE FUNCTION trigger_bites_update_daily_summary()
RETURNS TRIGGER AS $$
DECLARE
    v_session eating_sessions%ROWTYPE;
BEGIN
    SELECT * INTO v_session FROM eating_sessions WHERE uuid = NEW.meal_uuid;
    IF FOUND THEN
        -- Fire the same aggregation by doing a no-op update on the session row
        UPDATE eating_sessions SET updated_at = NOW() WHERE uuid = NEW.meal_uuid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_bites_rebuild_daily ON bites;
CREATE TRIGGER trigger_bites_rebuild_daily
    AFTER INSERT ON bites
    FOR EACH ROW EXECUTE FUNCTION trigger_bites_update_daily_summary();

-- ============================================================================
-- 4. Update analyticsModel to expose new columns (done in application layer)
-- ============================================================================
