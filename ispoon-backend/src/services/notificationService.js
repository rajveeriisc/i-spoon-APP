import * as NotificationModel from "../models/notificationModel.js";

/**
 * Notification Service - Business logic for notification system
 * Handles template processing, scheduling, and coordination
 */

class NotificationService {
    /**
     * Schedule a notification to be sent
     * @param {Object} options - Notification options
     * @param {number} options.userId - Target user ID
     * @param {string} options.type - Notification type (must match template)
     * @param {Object} options.data - Data to populate template placeholders
     * @param {Object} options.triggerSource - Source that triggered notification
     * @param {Date} options.scheduledFor - When to send (null = immediate)
     * @returns {Object} Created notification or null if throttled
     */
    async schedule({ userId, type, data = {}, triggerSource = {}, scheduledFor = null }) {
        try {
            // Get template
            const template = await NotificationModel.getTemplateByType(type);
            if (!template) {
                console.error(`[NotificationService] Template not found for type: ${type}`);
                return null;
            }

            // Check if notification can be sent (throttling & preferences)
            const canSend = await NotificationModel.canSendNotification(
                userId,
                type,
                template.priority
            );

            if (!canSend) {
                console.log(`[NotificationService] Notification throttled for user ${userId}, type ${type}`);
                return null;
            }

            // Process template with data
            const title = this._processTemplate(template.title_template, data);
            const body = this._processTemplate(template.body_template, data);

            // Create notification in history
            const notification = await NotificationModel.createNotification({
                user_id: userId,
                template_id: template.id,
                type: template.type,
                priority: template.priority,
                title,
                body,
                action_type: template.action_type,
                action_data: { ...template.action_data, ...data },
                scheduled_for: scheduledFor,
                trigger_source: triggerSource,
                delivery_method: 'push'
            });

            // Increment throttle counter
            await NotificationModel.incrementThrottleCounter(userId, type);

            console.log(`[NotificationService] Notification scheduled: ${notification.id} for user ${userId}`);

            // If immediate, trigger delivery
            if (!scheduledFor) {
                await this._deliverNotification(notification);
            }

            return notification;
        } catch (error) {
            console.error('[NotificationService] Error scheduling notification:', error);
            return null;
        }
    }

    /**
     * Process template string by replacing {{placeholders}} with data values
     * @param {string} template - Template string with {{key}} placeholders
     * @param {Object} data - Data object with replacement values
     * @returns {string} Processed string
     */
    _processTemplate(template, data) {
        let result = template;
        Object.keys(data).forEach(key => {
            const placeholder = new RegExp(`{{${key}}}`, 'g');
            result = result.replace(placeholder, data[key]);
        });
        return result;
    }

    /**
     * Deliver notification via FCM
     * @param {Object} notification - Notification object from database
     */
    async _deliverNotification(notification) {
        try {
            // Get user's FCM token
            const prefs = await NotificationModel.getUserPreferences(notification.user_id);

            if (!prefs || !prefs.fcm_token) {
                console.log(`[NotificationService] No FCM token for user ${notification.user_id}`);
                await NotificationModel.updateNotificationStatus(
                    notification.id,
                    'failed',
                    'No FCM token'
                );
                return;
            }

            // Import FCM service dynamically to avoid circular dependencies
            const { default: FCMService } = await import('./fcmService.js');

            // Send via FCM
            const result = await FCMService.sendNotification(notification, prefs.fcm_token);

            if (result.success) {
                await NotificationModel.updateNotificationStatus(notification.id, 'sent');
                console.log(`[NotificationService] Notification sent to user ${notification.user_id}`);
            } else {
                await NotificationModel.updateNotificationStatus(
                    notification.id,
                    'failed',
                    result.error
                );

                // Remove invalid FCM token
                if (result.shouldRemoveToken) {
                    await NotificationModel.updateUserPreferences(notification.user_id, {
                        fcm_token: null
                    });
                    console.log(`[NotificationService] Removed invalid FCM token for user ${notification.user_id}`);
                }
            }
        } catch (error) {
            console.error('[NotificationService] Error delivering notification:', error);
            await NotificationModel.updateNotificationStatus(
                notification.id,
                'failed',
                error.message
            );
        }
    }

    /**
     * Process pending notifications (for cron job)
     * @param {number} batchSize - How many to process at once
     */
    async processPendingNotifications(batchSize = 100) {
        try {
            const pending = await NotificationModel.getPendingNotifications(batchSize);
            console.log(`[NotificationService] Processing ${pending.length} pending notifications`);

            for (const notification of pending) {
                await this._deliverNotification(notification);
            }

            return pending.length;
        } catch (error) {
            if (error.code === 'EAI_AGAIN' || error.code === 'ETIMEDOUT') {
                console.warn(`[NotificationService] Network error connection to DB (processPendingNotifications): ${error.code} - Request skipped.`);
            } else {
                console.error('[NotificationService] Error processing pending notifications:', error);
            }
            return 0;
        }
    }

    /**
     * Mark notification as opened (called from client)
     * @param {number} notificationId - Notification ID
     */
    async markOpened(notificationId) {
        return await NotificationModel.markNotificationOpened(notificationId);
    }

    /**
     * Mark notification action taken (called from client)
     * @param {number} notificationId - Notification ID
     */
    async markActionTaken(notificationId) {
        return await NotificationModel.markNotificationActionTaken(notificationId);
    }

    /**
     * Get user's notification history
     * @param {number} userId - User ID
     * @param {number} limit - How many to return
     * @param {number} offset - Pagination offset
     */
    async getUserHistory(userId, limit = 50, offset = 0) {
        return await NotificationModel.getUserNotificationHistory(userId, limit, offset);
    }

    /**
     * Cleanup old notifications (for cron job)
     */
    async cleanupOld() {
        const deleted = await NotificationModel.cleanupOldNotifications();
        console.log(`[NotificationService] Cleaned up ${deleted} old notifications`);
        return deleted;
    }
}

// Export singleton instance
export default new NotificationService();
