-- ============================================================================
-- 004_remove_unused_fields.sql
-- Remove unused weight_grams from bites table and temperature_logs table
-- Created: 2026-01-12
-- ============================================================================

-- Remove weight_grams column from bites table
-- This field was never used in production - only in mock data
ALTER TABLE bites DROP COLUMN IF EXISTS weight_grams;

-- Remove temperature_logs table
-- Temperature data is now stored in meals table (avg_food_temp_c, max_food_temp_c, min_food_temp_c)
DROP TABLE IF EXISTS temperature_logs;

-- Add comment for clarity
COMMENT ON TABLE bites IS 'Bite events during meals - tracks tremor data per bite';
COMMENT ON COLUMN bites.tremor_magnitude_rad_s IS 'Tremor magnitude in radians per second';
COMMENT ON COLUMN bites.tremor_frequency_hz IS 'Tremor frequency in Hertz';
