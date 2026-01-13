import express from "express";
import * as MealsController from "../controllers/mealsController.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

// All routes require authentication
router.use(protect);

// Meal CRUD
router.get("/", MealsController.getMeals);
router.get("/:id", MealsController.getMealDetails);
router.post("/", MealsController.createMeal);
router.put("/:id", MealsController.updateMeal);
router.delete("/:id", MealsController.deleteMeal);

// Batch data insertion
router.post("/:id/bites", MealsController.addBitesToMeal);
router.post("/:id/temperature", MealsController.updateMealTemperature);

export default router;
