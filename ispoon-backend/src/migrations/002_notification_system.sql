-- ============================================================================
-- 002_notification_system.sql
-- Notification System Tables for SmartSpoon
-- ============================================================================

-- 1. Notification Templates
CREATE TABLE IF NOT EXISTS notification_templates (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL UNIQUE,
    category VARCHAR(20) NOT NULL CHECK (category IN ('health', 'achievement', 'engagement', 'system')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    action_type VARCHAR(50),
    action_data JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. User Notification Preferences
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled BOOLEAN DEFAULT TRUE,
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '07:00',
    
    -- Category toggles
    health_alerts_enabled BOOLEAN DEFAULT TRUE,
    achievement_enabled BOOLEAN DEFAULT TRUE,
    engagement_enabled BOOLEAN DEFAULT TRUE,
    system_alerts_enabled BOOLEAN DEFAULT TRUE,
    
    -- Frequency preferences
    max_daily_notifications INT DEFAULT 5,
    weekly_digest_enabled BOOLEAN DEFAULT TRUE,
    weekly_digest_day INT DEFAULT 0, -- 0 = Sunday
    weekly_digest_time TIME DEFAULT '20:00',
    
    -- Device tokens for FCM
    fcm_token TEXT,
    fcm_token_updated_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Notification History
CREATE TABLE IF NOT EXISTS notification_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id INT REFERENCES notification_templates(id),
    type VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    action_type VARCHAR(50),
    action_data JSONB,
    
    -- Delivery tracking
    scheduled_for TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,
    action_taken_at TIMESTAMPTZ,
    
    -- Metadata
    trigger_source JSONB,
    delivery_method VARCHAR(20) CHECK (delivery_method IN ('push', 'in_app', 'email')),
    delivery_status VARCHAR(20) DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'sent', 'delivered', 'failed', 'cancelled')),
    error_message TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Notification Throttling Tracker
CREATE TABLE IF NOT EXISTS notification_throttle_log (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notification_date DATE NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    count INT DEFAULT 0,
    last_sent_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, notification_date, notification_type)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_notification_templates_type ON notification_templates(type);
CREATE INDEX IF NOT EXISTS idx_notification_templates_active ON notification_templates(is_active);

CREATE INDEX IF NOT EXISTS idx_notification_history_user_date ON notification_history(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_history_status ON notification_history(delivery_status, scheduled_for);
CREATE INDEX IF NOT EXISTS idx_notification_history_type ON notification_history(type);

CREATE INDEX IF NOT EXISTS idx_notification_throttle_user_date ON notification_throttle_log(user_id, notification_date);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Updated At Trigger for templates
DROP TRIGGER IF EXISTS update_notification_templates_updated_at ON notification_templates;
CREATE TRIGGER update_notification_templates_updated_at
    BEFORE UPDATE ON notification_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Updated At Trigger for preferences
DROP TRIGGER IF EXISTS update_user_notification_preferences_updated_at ON user_notification_preferences;
CREATE TRIGGER update_user_notification_preferences_updated_at
    BEFORE UPDATE ON user_notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Auto-create default preferences for new users
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_create_notification_preferences ON users;
CREATE TRIGGER trigger_create_notification_preferences
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_notification_preferences();

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if notification should be sent (respects throttling and preferences)
CREATE OR REPLACE FUNCTION can_send_notification(
    p_user_id BIGINT,
    p_type VARCHAR(50),
    p_priority VARCHAR(20)
) RETURNS BOOLEAN AS $$
DECLARE
    v_prefs RECORD;
    v_count INT;
    v_total_today INT;
    v_category VARCHAR(20);
BEGIN
    -- Get user preferences
    SELECT * INTO v_prefs FROM user_notification_preferences WHERE user_id = p_user_id;
    
    -- If row doesn't exist or notifications globally disabled
    IF NOT FOUND OR NOT v_prefs.enabled THEN 
        RETURN FALSE; 
    END IF;
    
    -- CRITICAL always sends (for system alerts)
    IF p_priority = 'CRITICAL' THEN 
        RETURN TRUE; 
    END IF;
    
    -- Check quiet hours (only for non-critical)
    IF CURRENT_TIME BETWEEN v_prefs.quiet_hours_start AND v_prefs.quiet_hours_end THEN
        RETURN FALSE;
    END IF;
    
    -- Get category from template
    SELECT category INTO v_category FROM notification_templates WHERE type = p_type;
    
    -- Check category-specific toggles
    IF v_category = 'health' AND NOT v_prefs.health_alerts_enabled THEN RETURN FALSE; END IF;
    IF v_category = 'achievement' AND NOT v_prefs.achievement_enabled THEN RETURN FALSE; END IF;
    IF v_category = 'engagement' AND NOT v_prefs.engagement_enabled THEN RETURN FALSE; END IF;
    IF v_category = 'system' AND NOT v_prefs.system_alerts_enabled THEN RETURN FALSE; END IF;
    
    -- Check type-specific count for today
    SELECT COALESCE(count, 0) INTO v_count 
    FROM notification_throttle_log 
    WHERE user_id = p_user_id 
      AND notification_date = CURRENT_DATE 
      AND notification_type = p_type;
    
    -- Priority-based type limits
    IF p_priority = 'HIGH' AND v_count >= 3 THEN RETURN FALSE; END IF;
    IF p_priority = 'MEDIUM' AND v_count >= 2 THEN RETURN FALSE; END IF;
    IF p_priority = 'LOW' AND v_count >= 1 THEN RETURN FALSE; END IF;
    
    -- Check total daily limit (excluding CRITICAL)
    SELECT COUNT(*) INTO v_total_today
    FROM notification_history
    WHERE user_id = p_user_id 
      AND DATE(created_at) = CURRENT_DATE
      AND priority != 'CRITICAL'
      AND delivery_status != 'cancelled';
    
    IF v_total_today >= v_prefs.max_daily_notifications THEN 
        RETURN FALSE; 
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Increment throttle counter
CREATE OR REPLACE FUNCTION increment_throttle_counter(
    p_user_id BIGINT,
    p_type VARCHAR(50)
) RETURNS VOID AS $$
BEGIN
    INSERT INTO notification_throttle_log (user_id, notification_date, notification_type, count, last_sent_at)
    VALUES (p_user_id, CURRENT_DATE, p_type, 1, NOW())
    ON CONFLICT (user_id, notification_date, notification_type) 
    DO UPDATE SET 
        count = notification_throttle_log.count + 1,
        last_sent_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEED DATA - Notification Templates
-- ============================================================================

INSERT INTO notification_templates (type, category, priority, title_template, body_template, action_type, action_data) VALUES
-- Health Notifications
('fast_eating_alert', 'health', 'HIGH', 'Slow Down!', 'You''re eating at {{pace}} bpm. Try 10-12 bpm for better digestion.', 'open_insights', '{"screen": "pace"}'),
('tremor_spike', 'health', 'HIGH', 'Tremor Alert', 'Tremor detected at {{magnitude}} rad/s. Consider taking a break.', 'open_insights', '{"screen": "tremor"}'),
('temperature_alert', 'health', 'HIGH', 'Temperature Warning', 'Food temperature is {{temp}}°C. {{message}}', null, null),
('hydration_reminder', 'health', 'MEDIUM', 'Stay Hydrated!', 'It''s been {{hours}} hours since your last meal.', null, null),

-- Achievement Notifications
('daily_goal_reached', 'achievement', 'MEDIUM', 'Goal Achieved! 🎉', 'Congrats! You''ve hit your {{goal}}-bite goal for today!', 'open_insights', '{"screen": "dashboard"}'),
('streak_milestone', 'achievement', 'MEDIUM', 'Streak Milestone! 🔥', '{{days}}-day streak! You''re building healthy habits!', 'open_profile', null),
('weekly_summary', 'achievement', 'LOW', 'Your Week in Review', 'This week: {{bites}} bites, avg pace {{pace}} bpm, {{trend}}', 'open_insights', '{"screen": "weekly"}'),
('personal_best', 'achievement', 'MEDIUM', 'New Record! ⭐', 'New {{metric}}: {{value}}. Keep it up!', 'open_insights', null),

-- Engagement Notifications
('meal_reminder', 'engagement', 'LOW', 'Meal Check-in', 'Haven''t logged {{meal_type}} yet. How''s your day going?', null, null),
('insight_available', 'engagement', 'LOW', 'New Insight', 'We noticed {{pattern}}. Tap to learn more.', 'open_insights', '{"screen": "patterns"}'),
('device_inactive', 'engagement', 'LOW', 'Miss You!', 'Connect your SmartSpoon to track progress.', 'open_devices', null),
('update_available', 'engagement', 'LOW', 'Update Available', 'SmartSpoon v{{version}} is here with {{features}}!', 'open_settings', null),

-- System Notifications
('low_battery', 'system', 'CRITICAL', 'Low Battery', 'SmartSpoon battery low ({{percent}}%). Charge soon.', null, null),
('sync_failed', 'system', 'CRITICAL', 'Sync Issue', 'Sync problems detected. Check your connection.', 'open_settings', null),
('firmware_update', 'system', 'CRITICAL', 'Device Update', 'Important update available. Update now for best performance.', 'open_devices', null)

ON CONFLICT (type) DO UPDATE SET
    title_template = EXCLUDED.title_template,
    body_template = EXCLUDED.body_template,
    updated_at = NOW();

-- ============================================================================
-- Migration Complete
-- ============================================================================

COMMENT ON TABLE notification_templates IS 'Defines all notification types with their templates and metadata';
COMMENT ON TABLE user_notification_preferences IS 'User-specific notification settings and FCM tokens';
COMMENT ON TABLE notification_history IS 'Complete audit trail of all notifications sent to users';
COMMENT ON TABLE notification_throttle_log IS 'Daily counters for throttling notification frequency';
