import * as MealModel from "../models/mealModel.js";
import { AppError } from "../utils/errors.js";

class MealService {
    async getUserMeals(userId, queryOptions) {
        const { limit = 20, offset = 0, mealType } = queryOptions;
        return await MealModel.getUserMeals(userId, {
            limit: parseInt(limit),
            offset: parseInt(offset),
            mealType
        });
    }

    async getMealDetails(mealId, userId) {
        const meal = await MealModel.getMealById(mealId);
        if (!meal) throw new AppError('Meal not found', 404);
        if (meal.user_id !== userId) throw new AppError('Unauthorized', 403);
        return meal;
    }

    async createMeal(mealData, userId) {
        // Use upsert when uuid is present so repeated syncs of the same meal
        // don't create duplicates — idempotent sync is safe to retry
        if (mealData.uuid) {
            return await MealModel.upsertMealByUuid({ ...mealData, user_id: userId });
        }
        return await MealModel.createMeal({ ...mealData, user_id: userId });
    }

    async updateMeal(mealId, userId, updateData) {
        const existingMeal = await MealModel.getMealById(mealId);
        if (!existingMeal) throw new AppError('Meal not found', 404);
        if (existingMeal.user_id !== userId) throw new AppError('Unauthorized', 403);

        return await MealModel.updateMeal(mealId, updateData);
    }

    async deleteMeal(mealId, userId) {
        const meal = await MealModel.getMealById(mealId);
        if (!meal) throw new AppError('Meal not found', 404);
        if (meal.user_id !== userId) throw new AppError('Unauthorized', 403);

        await MealModel.deleteMeal(mealId);
        return { success: true, message: 'Meal deleted successfully' };
    }

    async updateMealTemperature(mealId, userId, temperatureData) {
        const meal = await MealModel.getMealById(mealId);
        if (!meal) throw new AppError('Meal not found', 404);
        if (meal.user_id !== userId) throw new AppError('Unauthorized', 403);

        return await MealModel.updateMeal(mealId, {
            avg_food_temp_c: temperatureData.avg_food_temp_c,
            max_food_temp_c: temperatureData.max_food_temp_c,
            min_food_temp_c: temperatureData.min_food_temp_c,
        });
    }
}

export default new MealService();
