import * as AnalyticsModel from "../models/analyticsModel.js";
import { AppError } from "../utils/errors.js";

class AnalyticsService {
    async getDashboard(userId, daysParam) {
        const rawDays = parseInt(daysParam, 10);
        const days = (!isNaN(rawDays) && rawDays > 0 && rawDays <= 365) ? rawDays : 90;

        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);

        const start = startDate.toISOString().split('T')[0];
        const end = endDate.toISOString().split('T')[0];

        const [dailyData, summary] = await Promise.all([
            AnalyticsModel.getDailyAnalytics(userId, start, end),
            AnalyticsModel.getAnalyticsSummary(userId, start, end),
        ]);

        return { daily_data: dailyData, summary };
    }

    async getTodayAnalytics(userId) {
        const today = new Date().toISOString().split('T')[0];
        const analytics = await AnalyticsModel.getAnalyticsForDate(userId, today);

        if (!analytics) {
            return { total_bites: 0, avg_tremor_magnitude: null, meal_breakdown: {} };
        }
        return analytics;
    }

    async getAnalyticsByDate(userId, date) {
        const analytics = await AnalyticsModel.getAnalyticsForDate(userId, date);
        if (!analytics) throw new AppError('No data for this date', 404);
        return analytics;
    }

    async getSummary(userId, startDate, endDate) {
        const summary = await AnalyticsModel.getAnalyticsSummary(userId, startDate, endDate);
        return summary;
    }
}

export default new AnalyticsService();
