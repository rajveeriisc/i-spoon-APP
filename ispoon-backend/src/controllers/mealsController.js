import * as MealModel from "../models/mealModel.js";
import * as BiteModel from "../models/biteModel.js";
import NotificationService from "../services/notificationService.js";

/**
 * Meals Controller - Handles meal-related API endpoints
 */

// GET /api/meals - Get user's meals
export const getMeals = async (req, res) => {
    try {
        const userId = req.user.id;
        const { limit = 20, offset = 0, meal_type } = req.query;

        const meals = await MealModel.getUserMeals(userId, {
            limit: parseInt(limit),
            offset: parseInt(offset),
            mealType: meal_type
        });

        res.json({ success: true, meals });
    } catch (error) {
        console.error("Get meals error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch meals" });
    }
};

// GET /api/meals/:id - Get single meal with details
export const getMealDetails = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const meal = await MealModel.getMealById(id);

        if (!meal) {
            return res.status(404).json({ success: false, message: "Meal not found" });
        }

        if (meal.user_id !== userId) {
            return res.status(403).json({ success: false, message: "Unauthorized" });
        }

        // Get associated data
        const bites = await BiteModel.getBitesForMeal(id);
        const tremorAnalysis = await BiteModel.getTremorAnalysisForMeal(id);

        res.json({
            success: true,
            meal: {
                ...meal,
                bites,
                tremor_analysis: tremorAnalysis
                // Temperature data is now in meal columns: avg_food_temp_c, max_food_temp_c, min_food_temp_c
            }
        });
    } catch (error) {
        console.error("Get meal details error:", error);
        res.status(500).json({ success: false, message: "Failed to fetch meal details" });
    }
};

// POST /api/meals - Create new meal
export const createMeal = async (req, res) => {
    try {
        const userId = req.user.id;
        const mealData = {
            ...req.body,
            user_id: userId
        };

        const meal = await MealModel.createMeal(mealData);

        res.status(201).json({ success: true, meal });
    } catch (error) {
        console.error("Create meal error:", error);
        res.status(500).json({ success: false, message: "Failed to create meal" });
    }
};

// PUT /api/meals/:id - Update meal
export const updateMeal = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const existingMeal = await MealModel.getMealById(id);

        if (!existingMeal) {
            return res.status(404).json({ success: false, message: "Meal not found" });
        }

        if (existingMeal.user_id !== userId) {
            return res.status(403).json({ success: false, message: "Unauthorized" });
        }

        const updatedMeal = await MealModel.updateMeal(id, req.body);

        // Check for notification triggers
        if (updatedMeal.avg_pace_bpm && updatedMeal.avg_pace_bpm > 15) {
            // Fast eating alert
            await NotificationService.schedule({
                userId: updatedMeal.user_id,
                type: 'fast_eating_alert',
                data: { pace: updatedMeal.avg_pace_bpm },
                triggerSource: { meal_id: updatedMeal.id }
            });
        }

        res.json({ success: true, meal: updatedMeal });
    } catch (error) {
        console.error("Update meal error:", error);
        res.status(500).json({ success: false, message: "Failed to update meal" });
    }
};

// DELETE /api/meals/:id - Delete meal
export const deleteMeal = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const meal = await MealModel.getMealById(id);

        if (!meal) {
            return res.status(404).json({ success: false, message: "Meal not found" });
        }

        if (meal.user_id !== userId) {
            return res.status(403).json({ success: false, message: "Unauthorized" });
        }

        await MealModel.deleteMeal(id);

        res.json({ success: true, message: "Meal deleted successfully" });
    } catch (error) {
        console.error("Delete meal error:", error);
        res.status(500).json({ success: false, message: "Failed to delete meal" });
    }
};

// POST /api/meals/:id/bites - Add bites to meal (batch)
export const addBitesToMeal = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        const { bites } = req.body;

        const meal = await MealModel.getMealById(id);

        if (!meal) {
            return res.status(404).json({ success: false, message: "Meal not found" });
        }

        if (meal.user_id !== userId) {
            return res.status(403).json({ success: false, message: "Unauthorized" });
        }

        // Add meal_id to each bite
        const bitesWithMealId = bites.map(bite => ({ ...bite, meal_id: id }));

        const createdBites = await BiteModel.createBitesBatch(bitesWithMealId);

        // Update meal's total_bites count
        await MealModel.updateMeal(id, { total_bites: createdBites.length });

        res.status(201).json({ success: true, bites: createdBites });
    } catch (error) {
        console.error("Add bites error:", error);
        res.status(500).json({ success: false, message: "Failed to add bites" });
    }
};

// POST /api/meals/:id/temperature - Update meal temperature data
export const updateMealTemperature = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;
        const { avg_food_temp_c, max_food_temp_c, min_food_temp_c } = req.body;

        const meal = await MealModel.getMealById(id);

        if (!meal) {
            return res.status(404).json({ success: false, message: "Meal not found" });
        }

        if (meal.user_id !== userId) {
            return res.status(403).json({ success: false, message: "Unauthorized" });
        }

        // Update meal temperature columns directly
        const updatedMeal = await MealModel.updateMeal(id, {
            avg_food_temp_c,
            max_food_temp_c,
            min_food_temp_c
        });

        res.status(200).json({
            success: true,
            meal: updatedMeal,
            message: "Temperature data updated successfully"
        });
    } catch (error) {
        console.error("Update temperature error:", error);
        res.status(500).json({ success: false, message: "Failed to update temperature data" });
    }
};
