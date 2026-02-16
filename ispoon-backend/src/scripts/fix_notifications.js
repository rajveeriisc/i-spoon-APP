import { pool } from "../config/db.js";

const fix = async () => {
    try {
        console.log("Fixing notification template...");

        // Insert system_alert template
        await pool.query(`
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
    `);

        console.log("✅ Template inserted/updated.");
        process.exit(0);
    } catch (error) {
        console.error("❌ Error:", error);
        process.exit(1);
    }
};

fix();
