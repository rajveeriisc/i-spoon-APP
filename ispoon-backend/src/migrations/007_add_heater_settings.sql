-- ============================================================================
-- 007_add_heater_settings.sql
-- Add heater configuration columns to user_devices table
-- Created: 2026-01-23
-- ============================================================================

ALTER TABLE user_devices
ADD COLUMN IF NOT EXISTS heater_active BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS heater_activation_temp DECIMAL(5,2) DEFAULT 15.0,
ADD COLUMN IF NOT EXISTS heater_max_temp DECIMAL(5,2) DEFAULT 40.0;
