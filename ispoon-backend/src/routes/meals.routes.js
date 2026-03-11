import express from "express";
import mealsController from "../controllers/mealsController.js";
import BiteController from "../controllers/biteController.js";
import { protect } from "../middleware/authMiddleware.js";
import { validateRequest } from "../middleware/validateRequest.js";
import {
  createMealSchema,
  updateMealSchema,
  updateMealTemperatureSchema
} from "../validators/meal.schema.js";
import {
  syncBitesSchema,
  getBitesSchema
} from "../validators/bite.schema.js";

// Currently bite schemas are not implemented yet, so fallback to legacy.
// import { validateSyncBites } from "../middleware/validation.js"; // This line is commented out or removed

const router = express.Router();

// All routes require authentication
router.use(protect);

// Meal CRUD
router.get("/", mealsController.getMeals);
router.get("/:id", mealsController.getMealDetails);
router.post("/", validateRequest(createMealSchema), mealsController.createMeal);
router.put("/:id", validateRequest(updateMealSchema), mealsController.updateMeal);
router.delete("/:id", mealsController.deleteMeal);

// Temperature
router.post("/:id/temperature", validateRequest(updateMealTemperatureSchema), mealsController.updateMealTemperature);

// Bites — keyed by meal uuid (mobile uses uuid as the stable identifier)
// These will be refactored in the next step
router.post("/:uuid/bites", validateRequest(syncBitesSchema), BiteController.syncBites);
router.get("/:uuid/bites", validateRequest(getBitesSchema), BiteController.getBites);

export default router;
