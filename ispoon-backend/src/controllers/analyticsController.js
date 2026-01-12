import * as AnalyticsModel from "../models/analyticsModel.js";

/**
 * Analytics Controller - Handles dashboard analytics endpoints
 */

// GET /api/analytics/dashboard - Get dashboard data (last 3 months)
export const getDashboard = async (req, res) => {
    try {
        const userId = req.user.id;
        const { days = 90 } = req.query;

        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - parseInt(days));

        // Get daily analytics (optimized query)  
        const dailyData = await AnalyticsModel.getDailyAnalytics(
            userId,
            startDate.toISOString().split('T')[0],
            endDate.toISOString().split('T')[0]
        );

        // Get summary statistics
        const summary = await AnalyticsModel.getAnalyticsSummary(
            userId,
            startDate.toISOString().split('T')[0],
            endDate.toISOString().split('T')[0]
        );

        // Get meal breakdown
        const mealBreakdown = await AnalyticsModel.getMealBreakdownSummary(
            userId,
            startDate.toISOString().split('T')[0],
            endDate.toISOString().split('T')[0]
        );

        // Get new breakdown tables data
        const biteBreakdown = await AnalyticsModel.getDailyBiteBreakdown(
            userId,
            startDate.toISOString().split('T')[0],
            endDate.toISOString().split('T')[0]
        );

        const tremorBreakdown = await AnalyticsModel.getDailyTremorBreakdown(
            userId,
            startDate.toISOString().split('T')[0],
            endDate.toISOString().split('T')[0]
        );

        res.json({
            success: true,
            dashboard: {
                daily_data: dailyData, // Legacy JSONB data
                summary,
                meal_breakdown: mealBreakdown,
                daily_bite_breakdown: biteBreakdown, // NEW: Structured breakdown
                daily_tremor_breakdown: tremorBreakdown // NEW: Structured breakdown
            }
        });
    } catch (error) {
        console.error("Get dashboard error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch dashboard data" });
    }
};

// GET /api/analytics/today - Get today's analytics
export const getTodayAnalytics = async (req, res) => {
    try {
        const userId = req.user.id;
        const today = new Date().toISOString().split('T')[0];

        const analytics = await AnalyticsModel.getAnalyticsForDate(userId, today);

        if (!analytics) {
            return res.json({
                success: true,
                analytics: {
                    total_bites: 0,
                    avg_tremor_magnitude: null,
                    meal_breakdown: {}
                }
            });
        }

        res.json({ success: true, analytics });
    } catch (error) {
        console.error("Get today analytics error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch today's analytics" });
    }
};

// GET /api/analytics/date/:date - Get analytics for specific date
export const getAnalyticsByDate = async (req, res) => {
    try {
        const userId = req.user.id;
        const { date } = req.params;

        const analytics = await AnalyticsModel.getAnalyticsForDate(userId, date);

        if (!analytics) {
            return res.status(404).json({ success: false, message: "No data for this date" });
        }

        res.json({ success: true, analytics });
    } catch (error) {
        console.error("Get analytics by date error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch analytics" });
    }
};

// GET /api/analytics/summary - Get summary for date range
export const getSummary = async (req, res) => {
    try {
        const userId = req.user.id;
        const { start_date, end_date } = req.query;

        if (!start_date || !end_date) {
            return res.status(400).json({
                success: false,
                message: "start_date and end_date are required"
            });
        }

        const summary = await AnalyticsModel.getAnalyticsSummary(userId, start_date, end_date);

        res.json({ success: true, summary });
    } catch (error) {
        console.error("Get summary error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch summary" });
    }
};

// POST /api/analytics/refresh/:date - Manually refresh analytics for a date    
export const refreshAnalytics = async (req, res) => {
    try {
        const userId = req.user.id;
        const { date } = req.params;

        await AnalyticsModel.refreshAnalyticsForDate(userId, date);

        const analytics = await AnalyticsModel.getAnalyticsForDate(userId, date);

        res.json({
            success: true,
            message: "Analytics refreshed successfully",
            analytics
        });
    } catch (error) {
        console.error("Refresh analytics error:", error);
        res.status(500).json({ success: false, message: "Failed to refresh analytics" });
    }
};
