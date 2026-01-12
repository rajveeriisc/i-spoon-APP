import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import * as NotificationController from "../controllers/notificationController.js";

const router = express.Router();

// All routes require authentication
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
