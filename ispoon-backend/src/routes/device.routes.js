import express from "express";
import { protect } from "../middleware/authMiddleware.js";
import deviceController from "../controllers/deviceController.js";
import { validateRequest } from "../middleware/validateRequest.js";
import { registerDeviceSchema, updateDeviceSettingsSchema } from "../validators/device.schema.js";

const router = express.Router();

// All device routes require authentication
router.get("/user-devices", protect, deviceController.getUserDevices);
router.post("/register", protect, validateRequest(registerDeviceSchema), deviceController.registerDevice);
router.patch("/:deviceId/settings", protect, validateRequest(updateDeviceSettingsSchema), deviceController.updateSettings);

export default router;
