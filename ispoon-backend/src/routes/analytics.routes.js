import express from "express";
import * as AnalyticsController from "../controllers/analyticsController.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

// All routes require authentication
router.use(protect);

// Dashboard and analytics
router.get("/dashboard", AnalyticsController.getDashboard);
router.get("/today", AnalyticsController.getTodayAnalytics);
router.get("/date/:date", AnalyticsController.getAnalyticsByDate);
router.get("/summary", AnalyticsController.getSummary);
router.post("/refresh/:date", AnalyticsController.refreshAnalytics);

export default router;
