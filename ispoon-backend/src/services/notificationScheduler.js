import cron from 'node-cron';
import NotificationService from '../services/notificationService.js';
import * as NotificationModel from '../models/notificationModel.js';
import { pool } from '../config/db.js';

/**
 * Notification Scheduler - Manages cron jobs for scheduled notifications
 * Handles daily summaries, weekly digests, reminders, and cleanup tasks
 */

class NotificationScheduler {
    constructor() {
        this.jobs = [];
    }

    /**
     * Initialize all cron jobs
     * Call this once at server startup
     */
    initialize() {
        console.log('[NotificationScheduler] Initializing cron jobs...');

        // Process pending notifications every minute
        this.jobs.push(cron.schedule('* * * * *', () => {
            this.processPendingNotifications();
        }));

        // Daily goal check - 11 PM every day
        this.jobs.push(cron.schedule('0 23 * * *', () => {
            this.checkDailyGoals();
        }));

        // Morning motivation - 8 AM every day
        this.jobs.push(cron.schedule('0 8 * * *', () => {
            this.sendMorningMotivation();
        }));

        // Weekly summary - Sunday 8 PM
        this.jobs.push(cron.schedule('0 20 * * 0', () => {
            this.sendWeeklySummaries();
        }));

        // Inactive device check - Daily at 2 PM
        this.jobs.push(cron.schedule('0 14 * * *', () => {
            this.checkInactiveDevices();
        }));

        // Cleanup old notifications - Daily at 3 AM
        this.jobs.push(cron.schedule('0 3 * * *', () => {
            this.cleanupOldNotifications();
        }));

        // Clear throttle logs - Daily at 4 AM
        this.jobs.push(cron.schedule('0 4 * * *', () => {
            this.clearOldThrottleLogs();
        }));

        // Test Notification - Every 2 minutes (DISABLED FOR PRODUCTION)
        // Uncomment the line below for testing only
        // this.jobs.push(cron.schedule('*/2 * * * *', () => { this.sendTestNotification(); }));

        console.log(`[NotificationScheduler] ${this.jobs.length} cron jobs initialized`);
    }

    /**
     * Process pending notifications that are scheduled
     */
    async processPendingNotifications() {
        try {
            const processed = await NotificationService.processPendingNotifications(100);
            if (processed > 0) {
                console.log(`[NotificationScheduler] Processed ${processed} pending notifications`);
            }
        } catch (error) {
            console.error('[NotificationScheduler] Error processing pending notifications:', error);
        }
    }

    /**
     * Check daily goals and send achievement notifications
     */
    async checkDailyGoals() {
        console.log('[NotificationScheduler] Checking daily goals...');
        try {
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayDate = yesterday.toISOString().split('T')[0];

            // Get users who met their goals yesterday
            const res = await pool.query(`
                SELECT dbb.user_id, dbb.total_bites, u.bite_goals
                FROM daily_bite_breakdown dbb
                JOIN users u ON dbb.user_id = u.id
                JOIN user_notification_preferences unp ON u.id = unp.user_id
                WHERE dbb.date = $1
                  AND unp.enabled = TRUE
                  AND unp.achievement_enabled = TRUE
            `, [yesterdayDate]);

            for (const row of res.rows) {
                const dailyGoal = row.bite_goals?.daily || 50;
                if (row.total_bites >= dailyGoal) {
                    await NotificationService.schedule({
                        userId: row.user_id,
                        type: 'daily_goal_reached',
                        data: {
                            bites: row.total_bites,
                            goal: dailyGoal
                        },
                        triggerSource: { date: yesterdayDate }
                    });
                }
            }

            console.log(`[NotificationScheduler] Checked ${res.rows.length} users for daily goals`);
        } catch (error) {
            console.error('[NotificationScheduler] Error checking daily goals:', error);
        }
    }

    /**
     * Send morning motivation/reminders
     */
    async sendMorningMotivation() {
        console.log('[NotificationScheduler] Sending morning motivation...');
        // This could check streaks, send encouragement, etc.
        // For now, we'll skip to avoid overwhelming users
    }

    /**
     * Send weekly summaries to users
     */
    async sendWeeklySummaries() {
        console.log('[NotificationScheduler] Sending weekly summaries...');
        try {
            // Get users who want weekly digests
            const res = await pool.query(`
                SELECT user_id 
                FROM user_notification_preferences
                WHERE enabled = TRUE 
                  AND weekly_digest_enabled = TRUE
                  AND weekly_digest_day = 0
            `);

            for (const { user_id } of res.rows) {
                // Get weekly stats
                const endDate = new Date();
                const startDate = new Date();
                startDate.setDate(startDate.getDate() - 7);

                const stats = await pool.query(`
                    SELECT 
                        SUM(total_bites) as total_bites,
                        AVG(avg_pace_bpm) as avg_pace,
                        COUNT(*) as days_tracked
                    FROM daily_bite_breakdown
                    WHERE user_id = $1 
                      AND date >= $2 
                      AND date <= $3
                `, [user_id, startDate.toISOString().split('T')[0], endDate.toISOString().split('T')[0]]);

                const weeklyStats = stats.rows[0];
                if (weeklyStats && weeklyStats.total_bites > 0) {
                    await NotificationService.schedule({
                        userId: user_id,
                        type: 'weekly_summary',
                        data: {
                            bites: weeklyStats.total_bites,
                            pace: weeklyStats.avg_pace?.toFixed(1) || 'N/A',
                            trend: weeklyStats.days_tracked >= 5 ? 'Great consistency!' : 'Keep it up!'
                        },
                        triggerSource: { week_start: startDate.toISOString().split('T')[0] }
                    });
                }
            }

            console.log(`[NotificationScheduler] Processed weekly summaries for ${res.rows.length} users`);
        } catch (error) {
            console.error('[NotificationScheduler] Error sending weekly summaries:', error);
        }
    }

    /**
     * Check for inactive devices and send re-engagement notifications
     */
    async checkInactiveDevices() {
        console.log('[NotificationScheduler] Checking inactive devices...');
        try {
            const threeDaysAgo = new Date();
            threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);

            const res = await pool.query(`
                SELECT DISTINCT d.user_id
                FROM devices d
                JOIN user_notification_preferences unp ON d.user_id = unp.user_id
                WHERE d.last_sync_at < $1
                  AND unp.enabled = TRUE
                  AND unp.engagement_enabled = TRUE
            `, [threeDaysAgo]);

            for (const { user_id } of res.rows) {
                await NotificationService.schedule({
                    userId: user_id,
                    type: 'device_inactive',
                    data: {},
                    triggerSource: { check_date: new Date().toISOString().split('T')[0] }
                });
            }

            console.log(`[NotificationScheduler] Found ${res.rows.length} inactive devices`);
        } catch (error) {
            console.error('[NotificationScheduler] Error checking inactive devices:', error);
        }
    }

    /**
     * Cleanup notifications older than 90 days
     */
    async cleanupOldNotifications() {
        console.log('[NotificationScheduler] Cleaning up old notifications...');
        try {
            const deleted = await NotificationService.cleanupOld();
            if (deleted > 0) {
                console.log(`[NotificationScheduler] Cleaned up ${deleted} old notifications`);
            }
        } catch (error) {
            console.error('[NotificationScheduler] Error cleaning up notifications:', error);
        }
    }

    /**
     * Clear old throttle logs (older than 30 days)
     */
    async clearOldThrottleLogs() {
        console.log('[NotificationScheduler] Clearing old throttle logs...');
        try {
            const res = await pool.query(`
                DELETE FROM notification_throttle_log
                WHERE notification_date < NOW() - INTERVAL '30 days'
            `);
            if (res.rowCount > 0) {
                console.log(`[NotificationScheduler] Cleared ${res.rowCount} old throttle logs`);
            }
        } catch (error) {
            console.error('[NotificationScheduler] Error clearing throttle logs:', error);
        }
    }

    /**
     * Send test notification to all users (bypasses throttling)
     */
    async sendTestNotification() {
        console.log('[NotificationScheduler] Sending test notification...');
        try {
            // Import FCM service
            const { default: FCMService } = await import('./fcmService.js');
            const NotificationModel = await import('../models/notificationModel.js');

            // Fetch all users with FCM tokens
            const res = await pool.query(`
                SELECT u.id, u.name, unp.fcm_token 
                FROM users u
                JOIN user_notification_preferences unp ON u.id = unp.user_id
                WHERE unp.fcm_token IS NOT NULL 
                  AND unp.enabled = TRUE
            `);

            let sentCount = 0;
            let failedCount = 0;

            for (const user of res.rows) {
                try {
                    // Create notification object
                    const notification = {
                        id: Date.now(), // Temporary ID
                        user_id: user.id,
                        type: 'system_alert',
                        priority: 'HIGH',
                        title: 'Test Notification',
                        body: `Hello ${user.name || 'User'}! This is a test notification at ${new Date().toLocaleTimeString()}`,
                        action_type: '',
                        action_data: { test: true }
                    };

                    // Send directly via FCM (bypasses throttling)
                    const result = await FCMService.sendNotification(notification, user.fcm_token);

                    if (result.success) {
                        sentCount++;
                        console.log(`✅ Test notification sent to user ${user.id}`);
                    } else {
                        failedCount++;
                        console.log(`❌ Failed to send to user ${user.id}: ${result.error}`);

                        // Remove invalid token
                        if (result.shouldRemoveToken) {
                            await NotificationModel.updateUserPreferences(user.id, { fcm_token: null });
                        }
                    }
                } catch (error) {
                    failedCount++;
                    console.error(`❌ Error sending to user ${user.id}:`, error.message);
                }
            }

            console.log(`[NotificationScheduler] Test notifications: ${sentCount} sent, ${failedCount} failed`);
        } catch (error) {
            console.error('[NotificationScheduler] Error sending test notification:', error);
        }
    }

    /**
     * Stop all cron jobs (for graceful shutdown)
     */
    stopAll() {
        console.log('[NotificationScheduler] Stopping all cron jobs...');
        this.jobs.forEach(job => job.stop());
        this.jobs = [];
    }
}

// Export singleton instance
export default new NotificationScheduler();
