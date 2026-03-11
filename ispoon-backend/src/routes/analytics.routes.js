import express from "express";
import analyticsController from "../controllers/analyticsController.js";
import { protect } from "../middleware/authMiddleware.js";
import { validateRequest } from "../middleware/validateRequest.js";
import {
    getDashboardSchema,
    getAnalyticsByDateSchema,
    getSummarySchema
} from "../validators/analytics.schema.js";

const router = express.Router();

// All routes require authentication
router.use(protect);

// Dashboard and analytics
router.get("/dashboard", validateRequest(getDashboardSchema), analyticsController.getDashboard);
router.get("/today", analyticsController.getTodayAnalytics);
router.get("/date/:date", validateRequest(getAnalyticsByDateSchema), analyticsController.getAnalyticsByDate);
router.get("/summary", validateRequest(getSummarySchema), analyticsController.getSummary);

export default router;
