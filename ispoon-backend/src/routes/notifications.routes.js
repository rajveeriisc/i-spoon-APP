import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import * as NotificationController from "../controllers/notificationController.js";
import NotificationService from "../services/notificationService.js";

const router = express.Router();

// Public test route
router.get("/test", (req, res) => res.json({ message: "Notification routes working" }));

// Manual test push notification endpoint (protected)
router.post("/test-push", protect, async (req, res) => {
    try {
        const userId = req.user.id;

        // Send immediate test notification
        const notification = await NotificationService.schedule({
            userId: userId,
            type: 'system_alert',
            title: 'Test Notification',
            body: `Manual test notification sent at ${new Date().toLocaleTimeString()}`,
            priority: 'HIGH',
            data: {
                test: true,
                timestamp: new Date().toISOString()
            }
        });

        if (notification) {
            res.json({
                success: true,
                message: "Test notification sent successfully",
                notification: {
                    id: notification.id,
                    title: notification.title,
                    body: notification.body,
                    created_at: notification.created_at
                }
            });
        } else {
            res.status(400).json({
                success: false,
                message: "Failed to send test notification (possibly throttled or no FCM token)"
            });
        }
    } catch (error) {
        console.error("Test push error:", error);
        res.status(500).json({
            success: false,
            message: "Error sending test notification",
            error: error.message
        });
    }
});

// All routes below require authentication
router.use(protect);

// Preferences management
router.get("/preferences", NotificationController.getPreferences);
router.put("/preferences", NotificationController.updatePreferences);

// FCM token registration
router.post("/fcm-token", NotificationController.registerFCMToken);

// Notification history
router.get("/history", NotificationController.getHistory);

// Notification tracking
router.post("/:id/opened", NotificationController.markOpened);
router.post("/:id/action", NotificationController.markActionTaken);

// Templates (for settings UI)
router.get("/templates", NotificationController.getTemplates);

export default router;

