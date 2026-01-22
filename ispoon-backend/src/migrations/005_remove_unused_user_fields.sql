-- ============================================================================
-- 005_remove_unused_user_fields.sql
-- Remove unused user profile fields that are not exposed in UI
-- Created: 2026-01-22
-- ============================================================================

-- Remove unused user profile fields
-- These fields exist in database but are not used in frontend UI

ALTER TABLE users DROP COLUMN IF EXISTS bio;
ALTER TABLE users DROP COLUMN IF EXISTS diet_type;
ALTER TABLE users DROP COLUMN IF EXISTS activity_level;
ALTER TABLE users DROP COLUMN IF EXISTS allergies;
ALTER TABLE users DROP COLUMN IF EXISTS emergency_contact;
ALTER TABLE users DROP COLUMN IF EXISTS bite_goals;

-- Add comments for remaining fields
COMMENT ON COLUMN users.name IS 'User full name';
COMMENT ON COLUMN users.phone IS 'User phone number';
COMMENT ON COLUMN users.location IS 'User location/city';
COMMENT ON COLUMN users.daily_goal IS 'Daily bite goal (total for all meals)';
COMMENT ON COLUMN users.notifications_enabled IS 'Whether push notifications are enabled';
COMMENT ON COLUMN users.avatar_url IS 'URL to user profile picture';
COMMENT ON COLUMN users.profile_metadata IS 'JSONB containing age, gender, weight';

-- ============================================================================
-- Migration Complete
-- Removed 6 unused columns: bio, diet_type, activity_level, allergies, 
-- emergency_contact, bite_goals
-- ============================================================================
