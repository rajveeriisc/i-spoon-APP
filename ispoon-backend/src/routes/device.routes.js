import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
    registerDevice,
    startDeviceSession,
    finishDeviceSession,
    recordHealth,
} from "../controllers/deviceController.js";

const router = express.Router();

// All device routes require authentication
router.post("/register", protect, registerDevice);
router.post("/sessions", protect, startDeviceSession);
router.patch("/sessions/:sessionId", protect, finishDeviceSession);
router.post("/health", protect, recordHealth);

export default router;
