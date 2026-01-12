import admin from 'firebase-admin';
import NotificationService from '../services/notificationService.js';

/**
 * FCM Delivery Service - Handles Firebase Cloud Messaging
 * Uses Firebase Admin SDK for server-side push notifications
 */

class FCMService {
    constructor() {
        this.messaging = null;
        this.initialized = false;
    }

    /**
     * Initialize Firebase Admin SDK
     * Should be called once at app startup
     */
    async initialize() {
        try {
            if (this.initialized) {
                return;
            }

            // Use the getFirebaseAdmin helper which handles initialization
            const { getFirebaseAdmin } = await import('../config/firebaseAdmin.js');
            const firebaseAdmin = getFirebaseAdmin();

            if (!firebaseAdmin) {
                console.warn('[FCMService] Firebase Admin not available - push notifications disabled');
                return;
            }

            this.messaging = firebaseAdmin.messaging();
            this.initialized = true;
            console.log('[FCMService] Initialized successfully');
        } catch (error) {
            console.warn('[FCMService] Initialization failed:', error.message);
            console.warn('[FCMService] Push notifications will not be sent');
            // Don't throw - allow server to start without FCM
        }
    }

    /**
     * Send a single notification via FCM
     * @param {Object} notification - Notification object from database
     * @param {string} fcmToken - User's FCM device token
     * @returns {Promise<Object>} FCM response
     */
    async sendNotification(notification, fcmToken) {
        if (!this.initialized) {
            throw new Error('FCM Service not initialized');
        }

        try {
            const message = {
                notification: {
                    title: notification.title,
                    body: notification.body
                },
                data: {
                    notification_id: notification.id.toString(),
                    type: notification.type,
                    priority: notification.priority,
                    action_type: notification.action_type || '',
                    action_data: JSON.stringify(notification.action_data || {})
                },
                android: {
                    priority: this._getAndroidPriority(notification.priority),
                    notification: {
                        channelId: this._getChannelId(notification.type),
                        sound: notification.priority === 'CRITICAL' ? 'default' : undefined,
                        priority: this._getAndroidPriority(notification.priority)
                    }
                },
                apns: {
                    payload: {
                        aps: {
                            sound: notification.priority === 'CRITICAL' ? 'default' : undefined,
                            badge: 1,
                            contentAvailable: true
                        }
                    },
                    headers: {
                        'apns-priority': notification.priority === 'CRITICAL' ? '10' : '5'
                    }
                },
                token: fcmToken
            };

            const response = await this.messaging.send(message);
            console.log(`[FCMService] Notification sent successfully: ${response}`);
            return { success: true, messageId: response };
        } catch (error) {
            console.error('[FCMService] Error sending notification:', error);

            // Handle specific FCM errors
            if (error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered') {
                return { success: false, error: 'Invalid or expired FCM token', shouldRemoveToken: true };
            }

            return { success: false, error: error.message };
        }
    }

    /**
     * Send notifications to multiple devices (batch)
     * @param {Array} notifications - Array of {notification, fcmToken} objects
     * @returns {Promise<Object>} Batch send results
     */
    async sendBatch(notifications) {
        if (!this.initialized) {
            throw new Error('FCM Service not initialized');
        }

        try {
            const messages = notifications.map(({ notification, fcmToken }) => ({
                notification: {
                    title: notification.title,
                    body: notification.body
                },
                data: {
                    notification_id: notification.id.toString(),
                    type: notification.type,
                    priority: notification.priority,
                    action_type: notification.action_type || '',
                    action_data: JSON.stringify(notification.action_data || {})
                },
                token: fcmToken
            }));

            const response = await this.messaging.sendAll(messages);
            console.log(`[FCMService] Batch sent: ${response.successCount}/${messages.length} successful`);

            return {
                successCount: response.successCount,
                failureCount: response.failureCount,
                responses: response.responses
            };
        } catch (error) {
            console.error('[FCMService] Batch send error:', error);
            throw error;
        }
    }

    /**
     * Get Android priority level from notification priority
     * @private
     */
    _getAndroidPriority(priority) {
        const priorityMap = {
            'CRITICAL': 'high',
            'HIGH': 'high',
            'MEDIUM': 'default',
            'LOW': 'default'
        };
        return priorityMap[priority] || 'default';
    }

    /**
     * Get Android notification channel ID based on type
     * @private
     */
    _getChannelId(type) {
        // Map notification types to Android channels
        // Channels should be created in the Flutter app
        if (type.includes('alert') || type.includes('spike') || type.includes('temperature')) {
            return 'health_alerts';
        }
        if (type.includes('goal') || type.includes('streak') || type.includes('best')) {
            return 'achievements';
        }
        if (type.includes('reminder') || type.includes('insight') || type.includes('inactive')) {
            return 'engagement';
        }
        if (type.includes('battery') || type.includes('sync') || type.includes('firmware')) {
            return 'system_alerts';
        }
        return 'default';
    }

    /**
     * Validate FCM token format
     * @param {string} token - FCM token to validate
     * @returns {boolean} True if valid format
     */
    isValidToken(token) {
        // Basic validation - FCM tokens are typically 152+ characters
        return typeof token === 'string' && token.length > 100;
    }
}

// Export singleton instance
export default new FCMService();
