import MealService from "../services/mealService.js";
import BaseController from "./BaseController.js";
import logger from "../utils/logger.js";
import asyncHandler from "../utils/asyncHandler.js";

/**
 * Meals Controller - Handles meal-related API endpoints
 */
class MealsController extends BaseController {
    constructor() {
        super();
    }

    // GET /api/meals - Get user's meals
    getMeals = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const meals = await MealService.getUserMeals(userId, req.query);

        logger.info('Meals fetched', { requestId: req.id, userId, count: meals.length });
        this.handleSuccess(res, { meals });
    });

    // GET /api/meals/:id - Get single meal with details
    getMealDetails = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const userId = req.user.id;

        const meal = await MealService.getMealDetails(id, userId);
        this.handleSuccess(res, { meal });
    });

    // POST /api/meals - Create new meal
    createMeal = asyncHandler(async (req, res) => {
        const userId = req.user.id;
        const meal = await MealService.createMeal(req.body, userId);

        logger.info('Meal created', { requestId: req.id, userId, mealId: meal.id });
        this.handleSuccess(res, { meal }, 201);
    });

    // PUT /api/meals/:id - Update meal
    updateMeal = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const userId = req.user.id;

        const updatedMeal = await MealService.updateMeal(id, userId, req.body);
        this.handleSuccess(res, { meal: updatedMeal });
    });

    // DELETE /api/meals/:id - Delete meal
    deleteMeal = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const userId = req.user.id;

        const result = await MealService.deleteMeal(id, userId);
        logger.info('Meal deleted', { requestId: req.id, userId, mealId: id });
        this.handleSuccess(res, result);
    });

    // POST /api/meals/:id/temperature - Update meal temperature data
    updateMealTemperature = asyncHandler(async (req, res) => {
        const { id } = req.params;
        const userId = req.user.id;

        const updatedMeal = await MealService.updateMealTemperature(id, userId, req.body);
        this.handleSuccess(res, {
            meal: updatedMeal,
            message: 'Temperature data updated successfully',
        });
    });
}

export default new MealsController();

