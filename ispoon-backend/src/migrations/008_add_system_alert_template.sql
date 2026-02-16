-- Add system_alert notification template
INSERT INTO notification_templates (type, category, priority, title_template, body_template, action_type, created_at)
VALUES 
(
    'system_alert', 
    'system', 
    'HIGH', 
    '{{title}}', 
    '{{body}}', 
    'open_settings', 
    NOW()
)
ON CONFLICT (type) DO UPDATE 
SET 
  title_template = EXCLUDED.title_template,
  body_template = EXCLUDED.body_template;
