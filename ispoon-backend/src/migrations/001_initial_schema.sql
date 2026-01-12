-- ============================================================================
-- 001_initial_schema.sql
-- Consolidated Baseline Schema for SmartSpoon
-- Represents the current final state as of Dec 30, 2025
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- 2. ENUMS (LEGACY - Kept for compatibility if needed, though mostly using strings now)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'device_status_enum') THEN
        CREATE TYPE device_status_enum AS ENUM ('active', 'inactive', 'maintenance', 'retired');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tremor_level_enum') THEN
        CREATE TYPE tremor_level_enum AS ENUM ('low', 'moderate', 'high');
    END IF;
END $$;

-- 3. HELPER FUNCTIONS
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. CORE TABLES

-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email CITEXT UNIQUE NOT NULL,
    password TEXT,
    name TEXT,
    phone TEXT,
    location TEXT,
    bio TEXT,
    diet_type TEXT,
    activity_level TEXT,
    allergies TEXT[],
    daily_goal INTEGER, -- Legacy: use bite_goals JSONB instead
    notifications_enabled BOOLEAN DEFAULT TRUE,
    emergency_contact TEXT,
    avatar_url TEXT,
    firebase_uid VARCHAR(255) UNIQUE,
    auth_provider VARCHAR(50) DEFAULT 'email',
    email_verified BOOLEAN DEFAULT FALSE,
    profile_metadata JSONB DEFAULT '{}', -- {age, gender, height_cm, weight_kg}
    bite_goals JSONB DEFAULT '{"daily":50,"breakfast":15,"lunch":20,"dinner":15,"snack":5}',
    welcome_email_sent BOOLEAN DEFAULT FALSE,
    welcome_email_sent_at TIMESTAMPTZ,
    reset_token TEXT,
    reset_token_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Devices Table
CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mac_address_hash VARCHAR(64) UNIQUE NOT NULL,
    firmware_version VARCHAR(20),
    last_sync_at TIMESTAMPTZ,
    health_metrics JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Meals Table
CREATE TABLE IF NOT EXISTS meals (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    meal_type VARCHAR(20) CHECK (meal_type IN ('Breakfast', 'Lunch', 'Dinner', 'Snack')),
    total_bites INTEGER NOT NULL DEFAULT 0,
    avg_pace_bpm DECIMAL(5,2),
    tremor_index INTEGER,
    duration_minutes DECIMAL(6,2),
    avg_food_temp_c DECIMAL(5,2),
    max_food_temp_c DECIMAL(5,2),
    min_food_temp_c DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bites Table
CREATE TABLE IF NOT EXISTS bites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_id BIGINT NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    tremor_magnitude_rad_s DECIMAL(8,4),
    tremor_frequency_hz DECIMAL(6,2),
    weight_grams DECIMAL(6,2),
    is_valid BOOLEAN DEFAULT TRUE,
    sequence_number INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (meal_id, sequence_number)
);

-- Temperature Logs Table
CREATE TABLE IF NOT EXISTS temperature_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_id BIGINT NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    food_temp_c DECIMAL(5,2),
    ambient_temp_c DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ANALYTICS TABLES

-- Daily Analytics (JSONB - Legacy but kept for sync)
CREATE TABLE IF NOT EXISTS daily_analytics (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_bites INT DEFAULT 0,
    avg_tremor_magnitude DECIMAL(8,4),
    max_tremor_magnitude DECIMAL(8,4),
    avg_tremor_frequency DECIMAL(6,2),
    meal_breakdown JSONB DEFAULT '{}',
    tremor_distribution JSONB DEFAULT '{}',
    total_eating_duration_min DECIMAL(8,2),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, date)
);

-- Structured Bite Breakdown
CREATE TABLE IF NOT EXISTS daily_bite_breakdown (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    breakfast INT DEFAULT 0,
    lunch INT DEFAULT 0,
    dinner INT DEFAULT 0,
    snacks INT DEFAULT 0,
    total_bites INT DEFAULT 0,
    avg_pace_bpm DECIMAL(5,2),
    total_duration_min DECIMAL(6,2),
    avg_meal_duration_min DECIMAL(6,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, date)
);

-- Structured Tremor Breakdown
CREATE TABLE IF NOT EXISTS daily_tremor_breakdown (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    avg_magnitude DECIMAL(8,4),
    peak_magnitude DECIMAL(8,4),
    min_magnitude DECIMAL(8,4),
    avg_frequency_hz DECIMAL(6,2),
    dominant_level VARCHAR(20),
    level_value INT,
    total_tremor_events INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, date)
);

-- 6. AUTH TABLES

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

-- Email Verification Tokens
CREATE TABLE IF NOT EXISTS email_verification_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    token_expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. INDEXES
CREATE INDEX IF NOT EXISTS idx_users_profile_metadata ON users USING GIN(profile_metadata);
CREATE INDEX IF NOT EXISTS idx_users_bite_goals ON users USING GIN(bite_goals);
CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_meals_user_time ON meals(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_bites_meal_id ON bites(meal_id);
CREATE INDEX IF NOT EXISTS idx_temp_logs_meal_id ON temperature_logs(meal_id);
CREATE INDEX IF NOT EXISTS idx_daily_analytics_date ON daily_analytics(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_bite_breakdown_date ON daily_bite_breakdown(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_tremor_breakdown_date ON daily_tremor_breakdown(date DESC);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

-- 8. TRIGGERS

-- Updated At Triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_devices_updated_at ON devices;
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_meals_updated_at ON meals;
CREATE TRIGGER update_meals_updated_at BEFORE UPDATE ON meals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Daily Breakdown Triggers

CREATE OR REPLACE FUNCTION update_daily_bite_breakdown()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_bite_breakdown (
        user_id, date, 
        breakfast, lunch, dinner, snacks,
        total_bites, avg_pace_bpm, total_duration_min, avg_meal_duration_min
    )
    SELECT 
        user_id,
        DATE(started_at) as date,
        SUM(CASE WHEN meal_type = 'Breakfast' THEN total_bites ELSE 0 END) as breakfast,
        SUM(CASE WHEN meal_type = 'Lunch' THEN total_bites ELSE 0 END) as lunch,
        SUM(CASE WHEN meal_type = 'Dinner' THEN total_bites ELSE 0 END) as dinner,
        SUM(CASE WHEN meal_type = 'Snack' THEN total_bites ELSE 0 END) as snacks,
        SUM(total_bites) as total_bites,
        AVG(avg_pace_bpm) as avg_pace_bpm,
        SUM(duration_minutes) as total_duration_min,
        AVG(duration_minutes) as avg_meal_duration_min
    FROM meals
    WHERE user_id = NEW.user_id AND DATE(started_at) = DATE(NEW.started_at)
    GROUP BY user_id, DATE(started_at)
    ON CONFLICT (user_id, date) DO UPDATE SET
        breakfast = EXCLUDED.breakfast,
        lunch = EXCLUDED.lunch,
        dinner = EXCLUDED.dinner,
        snacks = EXCLUDED.snacks,
        total_bites = EXCLUDED.total_bites,
        avg_pace_bpm = EXCLUDED.avg_pace_bpm,
        total_duration_min = EXCLUDED.total_duration_min,
        avg_meal_duration_min = EXCLUDED.avg_meal_duration_min,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_daily_bite_breakdown ON meals;
CREATE TRIGGER trigger_update_daily_bite_breakdown AFTER INSERT OR UPDATE ON meals FOR EACH ROW EXECUTE FUNCTION update_daily_bite_breakdown();

-- Temperature Trigger
CREATE OR REPLACE FUNCTION update_meal_temperature_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE meals
    SET 
        avg_food_temp_c = (SELECT AVG(food_temp_c) FROM temperature_logs WHERE meal_id = NEW.meal_id AND food_temp_c IS NOT NULL),
        max_food_temp_c = (SELECT MAX(food_temp_c) FROM temperature_logs WHERE meal_id = NEW.meal_id AND food_temp_c IS NOT NULL),
        min_food_temp_c = (SELECT MIN(food_temp_c) FROM temperature_logs WHERE meal_id = NEW.meal_id AND food_temp_c IS NOT NULL)
    WHERE id = NEW.meal_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_meal_temperature_stats ON temperature_logs;
CREATE TRIGGER trigger_update_meal_temperature_stats AFTER INSERT OR UPDATE ON temperature_logs FOR EACH ROW EXECUTE FUNCTION update_meal_temperature_stats();

-- ============================================================================
-- Initial Setup Complete
-- ============================================================================
