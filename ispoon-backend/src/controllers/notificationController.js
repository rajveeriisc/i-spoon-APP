import * as NotificationModel from "../models/notificationModel.js";

/**
 * Notification Preferences Controller - Handles notification settings API
 */

// GET /api/notifications/preferences - Get user's notification preferences
export const getPreferences = async (req, res) => {
    try {
        const userId = req.user.id;
        const preferences = await NotificationModel.getUserPreferences(userId);

        if (!preferences) {
            return res.status(404).json({
                success: false,
                message: "Preferences not found"
            });
        }

        // Don't send FCM token to client
        const { fcm_token, ...safePreferences } = preferences;

        res.json({
            success: true,
            preferences: safePreferences
        });
    } catch (error) {
        console.error("Get preferences error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to fetch preferences"
        });
    }
};

// PUT /api/notifications/preferences - Update notification preferences
export const updatePreferences = async (req, res) => {
    try {
        const userId = req.user.id;
        const updates = req.body;

        // Don't allow direct FCM token updates through this endpoint
        delete updates.fcm_token;

        const preferences = await NotificationModel.updateUserPreferences(userId, updates);

        if (!preferences) {
            return res.status(404).json({
                success: false,
                message: "Preferences not found"
            });
        }

        // Don't send FCM token to client
        const { fcm_token, ...safePreferences } = preferences;

        res.json({
            success: true,
            preferences: safePreferences,
            message: "Preferences updated successfully"
        });
    } catch (error) {
        console.error("Update preferences error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to update preferences"
        });
    }
};

// POST /api/notifications/fcm-token - Register FCM token
export const registerFCMToken = async (req, res) => {
    try {
        const userId = req.user.id;
        const { fcm_token } = req.body;

        if (!fcm_token) {
            return res.status(400).json({
                success: false,
                message: "FCM token is required"
            });
        }

        await NotificationModel.updateUserPreferences(userId, { fcm_token });

        res.json({
            success: true,
            message: "FCM token registered successfully"
        });
    } catch (error) {
        console.error("Register FCM token error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to register FCM token"
        });
    }
};

// GET /api/notifications/history - Get notification history
export const getHistory = async (req, res) => {
    try {
        const userId = req.user.id;
        const { limit = 50, offset = 0 } = req.query;

        const history = await NotificationModel.getUserNotificationHistory(
            userId,
            parseInt(limit),
            parseInt(offset)
        );

        res.json({
            success: true,
            notifications: history,
            pagination: {
                limit: parseInt(limit),
                offset: parseInt(offset),
                total: history.length
            }
        });
    } catch (error) {
        console.error("Get history error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to fetch notification history"
        });
    }
};

// POST /api/notifications/:id/opened - Mark notification as opened
export const markOpened = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const notification = await NotificationModel.markNotificationOpened(id);

        if (!notification) {
            return res.status(404).json({
                success: false,
                message: "Notification not found"
            });
        }

        // Verify ownership
        if (notification.user_id !== userId) {
            return res.status(403).json({
                success: false,
                message: "Unauthorized"
            });
        }

        res.json({
            success: true,
            notification
        });
    } catch (error) {
        console.error("Mark opened error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to mark notification as opened"
        });
    }
};

// POST /api/notifications/:id/action - Mark notification action taken
export const markActionTaken = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const notification = await NotificationModel.markNotificationActionTaken(id);

        if (!notification) {
            return res.status(404).json({
                success: false,
                message: "Notification not found"
            });
        }

        // Verify ownership
        if (notification.user_id !== userId) {
            return res.status(403).json({
                success: false,
                message: "Unauthorized"
            });
        }

        res.json({
            success: true,
            notification
        });
    } catch (error) {
        console.error("Mark action taken error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to mark action taken"
        });
    }
};

// GET /api/notifications/templates - Get all available notification types (for settings UI)
export const getTemplates = async (req, res) => {
    try {
        const templates = await NotificationModel.getAllTemplates();

        // Group by category for frontend display
        const grouped = templates.reduce((acc, template) => {
            if (!acc[template.category]) {
                acc[template.category] = [];
            }
            acc[template.category].push({
                type: template.type,
                title: template.title_template,
                description: template.body_template,
                priority: template.priority
            });
            return acc;
        }, {});

        res.json({
            success: true,
            templates: grouped
        });
    } catch (error) {
        console.error("Get templates error:", error);
        res.status(500).json({
            success: false,
            message: "Failed to fetch notification templates"
        });
    }
};
