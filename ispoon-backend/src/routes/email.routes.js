import express from 'express';
import { sendWelcomeEmail } from '../services/email.service.js';

const router = express.Router();

/**
 * Send Welcome Email (Public endpoint - no auth required)
 * Called from Flutter app after successful Firebase email verification
 */
router.post('/welcome', async (req, res) => {
    try {
        const { email, name } = req.body;

        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        console.log(`📧 Welcome email request for: ${email}`);

        // Send welcome email via Resend
        await sendWelcomeEmail({
            email,
            name: name || email.split('@')[0],
        });

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
