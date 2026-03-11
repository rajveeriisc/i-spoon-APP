import AnalyticsService from "../services/analyticsService.js";
import BaseController from "./BaseController.js";
import asyncHandler from "../utils/asyncHandler.js";

/**
 * Analytics Controller - Handles dashboard analytics endpoints
 */
class AnalyticsController extends BaseController {
    constructor() {
        super();
    }

    // GET /api/analytics/dashboard
    getDashboard = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const dashboard = await AnalyticsService.getDashboard(userId, req.query.days);
        this.handleSuccess(res, { dashboard });
    });

    // GET /api/analytics/today
    getTodayAnalytics = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const analytics = await AnalyticsService.getTodayAnalytics(userId);
        this.handleSuccess(res, { analytics });
    });

    // GET /api/analytics/date/:date
    getAnalyticsByDate = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const { date } = req.params;

        const analytics = await AnalyticsService.getAnalyticsByDate(userId, date);
        this.handleSuccess(res, { analytics });
    });

    // GET /api/analytics/summary
    getSummary = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const { start_date, end_date } = req.query;

        const summary = await AnalyticsService.getSummary(userId, start_date, end_date);
        this.handleSuccess(res, { summary });
    });
}

export default new AnalyticsController();
