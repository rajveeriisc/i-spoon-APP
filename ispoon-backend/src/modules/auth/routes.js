import express from "express";
import rateLimit from "express-rate-limit";
import { signup, login, logout, forgotPassword, resetPassword } from "../../controllers/authController.js";
import { socialLogin } from "../../controllers/socialAuthController.js";
import { verifyFirebaseToken } from "../../controllers/firebaseAuthController.js";

const router = express.Router();

// Deprecated for mobile app auth: use Firebase -> /api/auth/firebase/verify instead
router.post("/signup", signup);
router.post("/login", login);
router.post("/logout", logout);
router.post("/social", socialLogin);
router.post("/firebase/verify", verifyFirebaseToken);

const limiterTight = rateLimit({ windowMs: 15 * 60 * 1000, max: 5 });
router.post("/forgot", limiterTight, forgotPassword);
router.post("/reset", limiterTight, resetPassword);

export default router;


