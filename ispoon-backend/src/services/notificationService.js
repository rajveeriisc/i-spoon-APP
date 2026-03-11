import * as NotificationModel from "../models/notificationModel.js";

class NotificationService {
    /**
     * Send Realtime Notification
     * @param {Object} options Options containing userId, title, body, type, data
     */
    async schedule(options) {
        return this.sendRealtimeNotification(options);
    }

    async sendRealtimeNotification({ userId, title, body, type = 'system_alert', priority = 'DEFAULT', data = {} }) {
        if (!title || !body) {
            console.error('[NotificationService] Missing title or body for notification');
            return null;
        }

        try {
            // Save to DB
            const notification = await NotificationModel.createNotification({
                user_id: userId,
                title,
                body,
                type,
                priority,
                data
            });

            // Import FCM service
            const { default: FCMService } = await import('./fcmService.js');

            const tokens = await NotificationModel.getUserFCMTokens(userId);
            for (const token of tokens) {
                const result = await FCMService.sendNotification(notification, token);
                if (!result.success && result.shouldRemoveToken) {
                    await NotificationModel.removeFCMToken(token);
                }
            }

            console.log(`[NotificationService] Sent notification to user ${userId}`);
            return notification;
        } catch (error) {
            console.error('[NotificationService] Error sending notification:', error);
            return null;
        }
    }
}

// Export singleton instance
export default new NotificationService();
