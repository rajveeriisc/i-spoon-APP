-- ============================================================================
-- 006_create_telemetry_schema.sql
-- Create missing tables for Device Management and Telemetry
-- Syncs Database with deviceModel.js and telemetryModel.js
-- Created: 2026-01-22
-- ============================================================================

-- 1. DEVICE MANAGEMENT TABLES

-- Firmware Versions
CREATE TABLE IF NOT EXISTS firmware_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version VARCHAR(50) NOT NULL,
    hardware_revision VARCHAR(50), -- Null represents global version
    checksum VARCHAR(255),
    release_notes TEXT,
    released_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(version, hardware_revision)
);

-- User Devices (Linking users to hardware)
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    nickname VARCHAR(100),
    auto_connect BOOLEAN DEFAULT FALSE,
    is_primary BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMPTZ, -- Soft delete/unlink
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- 2. TELEMETRY CORE

-- Raw Payloads (Debug/Audit storage for raw binary/JSON)
CREATE TABLE IF NOT EXISTS raw_payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source VARCHAR(50), -- e.g. 'BLE', 'Wifi', 'Debug'
    payload TEXT, -- Base64 or JSON string
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device Sessions (A connection session)
CREATE TABLE IF NOT EXISTS device_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL,
    auth_session_id UUID, -- Link to auth session if needed
    firmware_version_id UUID REFERENCES firmware_versions(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    start_battery_percent INTEGER,
    end_battery_percent INTEGER,
    connection_type VARCHAR(50), -- 'BLE', 'WiFi'
    app_version VARCHAR(50),
    location_hint TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. DETAILED TELEMETRY SAMPLES

-- IMU Samples (Motion sensor data)
CREATE TABLE IF NOT EXISTS imu_samples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    accel_x INTEGER,
    accel_y INTEGER,
    accel_z INTEGER,
    gyro_x INTEGER,
    gyro_y INTEGER,
    gyro_z INTEGER,
    temperature_c DECIMAL(5,2),
    raw_payload_id UUID REFERENCES raw_payloads(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Temperature Samples (Precise thermal logging)
CREATE TABLE IF NOT EXISTS temperature_samples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    food_temp_c DECIMAL(5,2),
    heater_temp_c DECIMAL(5,2),
    utensil_temp_c DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Environment Samples
CREATE TABLE IF NOT EXISTS environment_samples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    ambient_temp_c DECIMAL(5,2),
    humidity_percent DECIMAL(5,2),
    pressure_hpa DECIMAL(8,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tremor Metrics (Aggregated/Calculated on device)
CREATE TABLE IF NOT EXISTS tremor_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL,
    magnitude DECIMAL(10,4),
    peak_frequency_hz DECIMAL(6,2),
    level VARCHAR(20), -- 'low', 'moderate', 'high'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bite Events (Detailed bite telemetry)
CREATE TABLE IF NOT EXISTS bite_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meal_id BIGINT REFERENCES meals(id) ON DELETE CASCADE,
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE SET NULL,
    recorded_at TIMESTAMPTZ,
    sequence_index INTEGER,
    weight_grams DECIMAL(10,2), 
    food_temp_c DECIMAL(5,2),
    tremor_magnitude DECIMAL(10,4),
    classification VARCHAR(50) DEFAULT 'valid',
    raw_payload_id UUID REFERENCES raw_payloads(id) ON DELETE SET NULL,
    ingestion_latency_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(meal_id, sequence_index)
);

-- Device Health Snapshots
CREATE TABLE IF NOT EXISTS device_health_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_device_id UUID REFERENCES user_devices(id) ON DELETE SET NULL,
    device_session_id UUID REFERENCES device_sessions(id) ON DELETE SET NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    battery_percent INTEGER,
    voltage DECIMAL(5,2),
    charge_cycles INTEGER,
    sensors_healthy BOOLEAN,
    fault_code VARCHAR(50),
    cpu_temp_c DECIMAL(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. INDEXES & TRIGGERS

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_device_sessions_user_device ON device_sessions(user_device_id);
CREATE INDEX IF NOT EXISTS idx_imu_samples_session ON imu_samples(device_session_id);
CREATE INDEX IF NOT EXISTS idx_bite_events_meal ON bite_events(meal_id);

-- Updated At Triggers
-- Updated At Triggers
DROP TRIGGER IF EXISTS update_firmware_updated_at ON firmware_versions;
CREATE TRIGGER update_firmware_updated_at BEFORE UPDATE ON firmware_versions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_devices_updated_at ON user_devices;
CREATE TRIGGER update_user_devices_updated_at BEFORE UPDATE ON user_devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_device_sessions_updated_at ON device_sessions;
CREATE TRIGGER update_device_sessions_updated_at BEFORE UPDATE ON device_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_bite_events_updated_at ON bite_events;
CREATE TRIGGER update_bite_events_updated_at BEFORE UPDATE ON bite_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
