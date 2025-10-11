import express from "express";
import rateLimit from "express-rate-limit";
import { signup, login, logout, forgotPassword, resetPassword } from "../../controllers/authController.js";

const router = express.Router();

router.post("/signup", signup);
router.post("/login", login);
router.post("/logout", logout);

const limiterTight = rateLimit({ windowMs: 15 * 60 * 1000, max: 5 });
router.post("/forgot", limiterTight, forgotPassword);
router.post("/reset", limiterTight, resetPassword);

export default router;


