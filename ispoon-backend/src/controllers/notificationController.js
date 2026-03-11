import * as NotificationModel from "../models/notificationModel.js";
import { pool } from "../config/db.js";
import asyncHandler from "../utils/asyncHandler.js";
import logger from "../utils/logger.js";
import { AppError } from "../utils/errors.js";

/**
 * Notification Controller - Handles notification settings API
 */

// GET /api/notifications/preferences
export const getPreferences = asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const result = await pool.query(
        `SELECT notifications_enabled FROM users WHERE id = $1`,
        [userId]
    );

    res.json({
        success: true,
        preferences: {
            enabled: result.rows[0]?.notifications_enabled ?? true,
        },
    });
});

// PUT /api/notifications/preferences
export const updatePreferences = asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { enabled } = req.body;

    if (typeof enabled !== 'boolean') {
        throw new AppError('enabled must be a boolean', 400);
    }

    await pool.query(
        `UPDATE users SET notifications_enabled = $1 WHERE id = $2`,
        [enabled, userId]
    );

    logger.info('Notification preferences updated', { requestId: req.id, userId, enabled });
    res.json({
        success: true,
        preferences: { enabled },
        message: 'Preferences updated successfully',
    });
});

// POST /api/notifications/fcm-token
export const registerFCMToken = asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const { fcm_token } = req.body;

    if (!fcm_token || typeof fcm_token !== 'string' || fcm_token.length < 10) {
        throw new AppError('A valid FCM token is required', 400);
    }

    await NotificationModel.addFCMToken(userId, fcm_token);

    logger.info('FCM token registered', { requestId: req.id, userId });
    res.json({ success: true, message: 'FCM token registered successfully' });
});

// GET /api/notifications/history
export const getHistory = asyncHandler(async (req, res) => {
    const userId = req.user.id;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = Math.min(Math.max(parseInt(req.query.offset, 10) || 0, 0), 10000);

    const history = await NotificationModel.getUserNotificationHistory(userId, limit, offset);

    res.json({
        success: true,
        notifications: history,
        pagination: { limit, offset, returned: history.length },
    });
});

// POST /api/notifications/:id/opened
export const markOpened = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id;

    const notification = await NotificationModel.markNotificationRead(id, userId);
    if (!notification) throw new AppError('Notification not found', 404);

    res.json({ success: true, notification });
});

// POST /api/notifications/:id/action
export const markActionTaken = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id;

    const notification = await NotificationModel.markNotificationRead(id, userId);
    if (!notification) throw new AppError('Notification not found', 404);

    res.json({ success: true, notification });
});

// GET /api/notifications/templates
export const getTemplates = asyncHandler(async (req, res) => {
    res.json({ success: true, templates: {} });
});
