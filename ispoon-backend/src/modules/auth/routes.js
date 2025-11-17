import express from "express";
import rateLimit from "express-rate-limit";
import { signup, login, logout, forgotPassword, resetPassword } from "../../controllers/authController.js";
import { verifyFirebaseToken, sendVerification } from "../../controllers/firebaseAuthController.js";

const router = express.Router();

router.post("/signup", signup);  // Register new user
router.post("/login", login);    // Login with email/password
router.post("/logout", logout);  // Logout (clears client token)

router.post("/firebase/verify", verifyFirebaseToken);                // Verify Firebase ID token
router.post("/firebase/send-verification", sendVerification);        // Send email verification

// Password Reset
const limiterTight = rateLimit({ windowMs: 15 * 60 * 1000, max: 5 });
router.post("/forgot", limiterTight, forgotPassword);  // Request password reset
router.post("/reset", limiterTight, resetPassword);    // Reset password with token

export default router;


