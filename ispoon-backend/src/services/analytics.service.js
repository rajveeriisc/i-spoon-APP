import * as analyticsRepo from '../repositories/analytics.repository.js';

/**
 * Analytics Service Layer
 * Business logic for user analytics, dashboards, and insights
 */

/**
 * Get complete user dashboard
 * @param {number} userId - User ID
 * @returns {Promise<Object>} Dashboard data
 */
export const getUserDashboardData = async (userId) => {
    try {
        const analytics = await analyticsRepo.getComprehensiveAnalytics(userId);

        return {
            success: true,
            data: analytics,
        };
    } catch (error) {
        console.error('Error fetching dashboard data:', error);
        throw new Error('Failed to fetch dashboard data');
    }
};

/**
 * Get bite trends for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days
 * @returns {Promise<Object>} Bite trends data
 */
export const getBiteTrends = async (userId, days = 30) => {
    try {
        const dailySummaries = await analyticsRepo.getDailyBiteSummaries(userId, days);

        // Transform for charting
        const chartData = dailySummaries.map(day => ({
            date: day.summary_date,
            bites: day.total_bites,
            goalMet: day.goal_met,
            avgPace: parseFloat(day.avg_pace_bpm) || 0,
        }));

        return {
            success: true,
            data: {
                chartData,
                summary: {
                    totalDays: dailySummaries.length,
                    avgBitesPerDay: chartData.reduce((sum, d) => sum + d.bites, 0) / chartData.length || 0,
                    daysGoalMet: chartData.filter(d => d.goalMet).length,
                },
            },
        };
    } catch (error) {
        console.error('Error fetching bite trends:', error);
        throw new Error('Failed to fetch bite trends');
    }
};

/**
 * Get tremor trends for a user
 * @param {number} userId - User ID
 * @param {number} days - Number of days
 * @returns {Promise<Object>} Tremor trends data
 */
export const getTremorTrends = async (userId, days = 30) => {
    try {
        const dailySummaries = await analyticsRepo.getDailyTremorSummaries(userId, days);

        const chartData = dailySummaries.map(day => ({
            date: day.summary_date,
            avgMagnitude: parseFloat(day.avg_magnitude) || 0,
            peakMagnitude: parseFloat(day.peak_magnitude) || 0,
            dominantLevel: day.dominant_level,
        }));

        return {
            success: true,
            data: {
                chartData,
                summary: {
                    avgMagnitude: chartData.reduce((sum, d) => sum + d.avgMagnitude, 0) / chartData.length || 0,
                    maxMagnitude: Math.max(...chartData.map(d => d.peakMagnitude)),
                },
            },
        };
    } catch (error) {
        console.error('Error fetching tremor trends:', error);
        throw new Error('Failed to fetch tremor trends');
    }
};

/**
 * Get weekly meal trends
 * @param {number} userId - User ID
 * @param {number} weeks - Number of weeks
 * @returns {Promise<Object>} Weekly trends data
 */
export const getWeeklyTrends = async (userId, weeks = 12) => {
    try {
        const weeklyData = await analyticsRepo.getWeeklyMealTrends(userId, weeks);

        const chartData = weeklyData.map(week => ({
            weekStart: week.week_start,
            weekEnd: week.week_end,
            meals: week.meals_count,
            totalBites: week.total_bites,
            avgTremor: parseFloat(week.avg_tremor_index) || 0,
        }));

        return {
            success: true,
            data: {
                chartData,
                summary: {
                    totalWeeks: chartData.length,
                    avgMealsPerWeek: chartData.reduce((sum, w) => sum + w.meals, 0) / chartData.length || 0,
                },
            },
        };
    } catch (error) {
        console.error('Error fetching weekly trends:', error);
        throw new Error('Failed to fetch weekly trends');
    }
};

/**
 * Get goal achievement data
 * @param {number} userId - User ID
 * @param {number} days - Number of days
 * @returns {Promise<Object>} Goal achievement data
 */
export const getGoalAchievement = async (userId, days = 30) => {
    try {
        const goalData = await analyticsRepo.getGoalAchievement(userId, days);

        return {
            success: true,
            data: {
                totalDays: parseInt(goalData.total_days) || 0,
                daysGoalMet: parseInt(goalData.days_goal_met) || 0,
                achievementPercentage: parseFloat(goalData.achievement_percentage) || 0,
            },
        };
    } catch (error) {
        console.error('Error fetching goal achievement:', error);
        throw new Error('Failed to fetch goal achievement');
    }
};

/**
 * Refresh analytics cache
 * @returns {Promise<Object>} Refresh status
 */
export const refreshAnalyticsCache = async () => {
    try {
        await analyticsRepo.refreshMaterializedViews();

        return {
            success: true,
            message: 'Analytics cache refreshed successfully',
            timestamp: new Date().toISOString(),
        };
    } catch (error) {
        console.error('Error refreshing analytics cache:', error);
        throw new Error('Failed to refresh analytics cache');
    }
};
