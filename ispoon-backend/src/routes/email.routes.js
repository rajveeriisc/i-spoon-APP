import express from 'express';
import { sendWelcomeEmail } from '../services/email.service.js';
import { pool } from '../config/db.js';

const router = express.Router();

/**
 * Send Welcome Email (Public endpoint - with database protection)
 * Called from Flutter app after successful Firebase email verification.
 * Will only send email if welcome_email_sent flag is false in database.
 */
router.post('/welcome', async (req, res) => {
    try {
        const { email, name } = req.body;

        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        console.log(`📧 Welcome email request for: ${email}`);

        // Check if welcome email was already sent
        const userResult = await pool.query(
            'SELECT id, welcome_email_sent FROM users WHERE email = $1',
            [email.toLowerCase()]
        );

        if (userResult.rows.length === 0) {
            console.log(`⚠️ User not found in database: ${email}`);
            return res.status(200).json({ message: 'User not found', skipped: true });
        }

        const user = userResult.rows[0];

        if (user.welcome_email_sent) {
            console.log(`⏭️ Welcome email already sent to ${email}, skipping.`);
            return res.status(200).json({ message: 'Welcome email already sent', skipped: true });
        }

        // Send welcome email via Resend
        await sendWelcomeEmail({
            email,
            name: name || email.split('@')[0],
        });

        // Mark as sent
        await pool.query(
            'UPDATE users SET welcome_email_sent = true, welcome_email_sent_at = NOW(), updated_at = NOW() WHERE id = $1',
            [user.id]
        );

        console.log(`✅ Welcome email sent and flagged for ${email}`);

        res.json({
            message: 'Welcome email sent successfully',
            email,
        });
    } catch (error) {
        console.error('❌ Welcome email endpoint error:', error);
        // Don't fail the request - email is not critical
        res.status(200).json({
            message: 'Email service unavailable',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined,
        });
    }
});

export default router;
