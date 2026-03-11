-- ============================================================================
-- 001_v2_baseline.sql
-- Streamlined V2 Schema for SmartSpoon
-- Represents the complete schema rewrite (Removed Legacy Tremor & Health Metrics)
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- 2. HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. CORE TABLES

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email CITEXT UNIQUE NOT NULL,
    password TEXT,
    name TEXT,
    avatar_url TEXT,
    notifications_enabled BOOLEAN DEFAULT TRUE,
    firebase_uid VARCHAR(255) UNIQUE,
    auth_provider VARCHAR(50) DEFAULT 'email',
    email_verified BOOLEAN DEFAULT FALSE,
    welcome_email_sent BOOLEAN DEFAULT FALSE,
    welcome_email_sent_at TIMESTAMPTZ,
    reset_token TEXT,
    reset_token_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Devices Table (Includes Heater Configuration)
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mac_address_hash VARCHAR(64) UNIQUE NOT NULL,
    firmware_version VARCHAR(20),
    heater_active BOOLEAN DEFAULT FALSE,
    heater_activation_temp DECIMAL(5,2) DEFAULT 15.0,
    heater_max_temp DECIMAL(5,2) DEFAULT 40.0,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Eating Sessions Table (Previously 'meals', now simplified)
CREATE TABLE IF NOT EXISTS eating_sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    meal_type VARCHAR(20) CHECK (meal_type IN ('Breakfast', 'Lunch', 'Dinner', 'Snack')),
    total_bites INTEGER NOT NULL DEFAULT 0,
    duration_minutes DECIMAL(6,2),
    avg_food_temp_c DECIMAL(5,2),
    max_food_temp_c DECIMAL(5,2),
    min_food_temp_c DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ANALYTICS TABLES

-- Daily Summaries (Replaces daily_bite_breakdown, daily_analytics, daily_tremor_breakdown)
CREATE TABLE IF NOT EXISTS daily_summaries (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_bites INT DEFAULT 0,
    total_eating_duration_min DECIMAL(8,2) DEFAULT 0,
    breakfast_bites INT DEFAULT 0,
    lunch_bites INT DEFAULT 0,
    dinner_bites INT DEFAULT 0,
    snack_bites INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, date)
);

-- 5. AUTH & SYSTEM TABLES

-- Refresh Tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    user_agent TEXT,
    ip_address INET,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- FCM Tokens
CREATE TABLE IF NOT EXISTS fcm_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    device_type VARCHAR(20),
    last_used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, token)
);

-- Notification History
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'system_alerts', 'sync_reminders', etc.
    priority VARCHAR(20) DEFAULT 'DEFAULT',
    read BOOLEAN DEFAULT FALSE,
    data JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 6. INDEXES
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_eating_sessions_user_time ON eating_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- 7. TRIGGERS

-- Updated At Triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_devices_updated_at ON devices;
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_eating_sessions_updated_at ON eating_sessions;
CREATE TRIGGER update_eating_sessions_updated_at BEFORE UPDATE ON eating_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Daily Summary Aggregation Trigger
CREATE OR REPLACE FUNCTION update_daily_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_summaries (
        user_id, date, 
        total_bites, total_eating_duration_min,
        breakfast_bites, lunch_bites, dinner_bites, snack_bites
    )
    SELECT 
        user_id,
        DATE(started_at) as date,
        SUM(total_bites) as total_bites,
        SUM(duration_minutes) as total_eating_duration_min,
        SUM(CASE WHEN meal_type = 'Breakfast' THEN total_bites ELSE 0 END) as breakfast_bites,
        SUM(CASE WHEN meal_type = 'Lunch' THEN total_bites ELSE 0 END) as lunch_bites,
        SUM(CASE WHEN meal_type = 'Dinner' THEN total_bites ELSE 0 END) as dinner_bites,
        SUM(CASE WHEN meal_type = 'Snack' THEN total_bites ELSE 0 END) as snack_bites
    FROM eating_sessions
    WHERE user_id = NEW.user_id AND DATE(started_at) = DATE(NEW.started_at)
    GROUP BY user_id, DATE(started_at)
    ON CONFLICT (user_id, date) DO UPDATE SET
        total_bites = EXCLUDED.total_bites,
        total_eating_duration_min = EXCLUDED.total_eating_duration_min,
        breakfast_bites = EXCLUDED.breakfast_bites,
        lunch_bites = EXCLUDED.lunch_bites,
        dinner_bites = EXCLUDED.dinner_bites,
        snack_bites = EXCLUDED.snack_bites,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_daily_summary ON eating_sessions;
CREATE TRIGGER trigger_update_daily_summary AFTER INSERT OR UPDATE ON eating_sessions FOR EACH ROW EXECUTE FUNCTION update_daily_summary();
