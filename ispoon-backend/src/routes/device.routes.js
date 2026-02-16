import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
    registerDevice,
    startDeviceSession,
    finishDeviceSession,
    recordHealth,
    updateSettings,
    getUserDevices,
} from "../controllers/deviceController.js";

const router = express.Router();

// All device routes require authentication
router.get("/user-devices", protect, getUserDevices);
router.post("/register", protect, registerDevice);
router.post("/sessions", protect, startDeviceSession);
router.patch("/sessions/:sessionId", protect, finishDeviceSession);
router.post("/health", protect, recordHealth);
router.patch("/user-devices/:userDeviceId/settings", protect, updateSettings);

export default router;
