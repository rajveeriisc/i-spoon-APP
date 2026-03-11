import * as BiteModel from "../models/biteModel.js";
import * as MealModel from "../models/mealModel.js";
import { AppError } from "../utils/errors.js";

class BiteService {
    async syncBites(mealUuid, userId, bitesData) {
        if (!Array.isArray(bitesData) || bitesData.length === 0) {
            throw new AppError('bites array is required and must not be empty', 400);
        }

        // Verify meal belongs to this user
        const meal = await MealModel.getMealByUuid(mealUuid);
        if (!meal) throw new AppError('Meal not found', 404);
        if (meal.user_id !== userId) throw new AppError('Unauthorized', 403);

        const inserted = await BiteModel.upsertBites(mealUuid, bitesData);

        return {
            synced: inserted.length,
            total: bitesData.length,
        };
    }

    async getBites(mealUuid, userId) {
        const meal = await MealModel.getMealByUuid(mealUuid);
        if (!meal) throw new AppError('Meal not found', 404);
        if (meal.user_id !== userId) throw new AppError('Unauthorized', 403);

        const bites = await BiteModel.getBitesForMeal(mealUuid);
        return bites;
    }
}

export default new BiteService();
