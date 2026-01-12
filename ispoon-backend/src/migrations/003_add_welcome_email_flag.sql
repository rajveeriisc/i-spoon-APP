-- ============================================================================
-- 003_add_welcome_email_flag.sql
-- Add welcome_email_sent flag to users table if missing
-- ============================================================================

DO $$
BEGIN
    -- Add welcome_email_sent column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'welcome_email_sent') THEN
        ALTER TABLE users ADD COLUMN welcome_email_sent BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add welcome_email_sent_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'welcome_email_sent_at') THEN
        ALTER TABLE users ADD COLUMN welcome_email_sent_at TIMESTAMPTZ;
    END IF;
END $$;
