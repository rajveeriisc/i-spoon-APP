import express from "express";
import {
    verifyFirebaseToken,
    requestEmailVerification,
} from "../controllers/firebaseAuthController.js";
import { protect } from "../middleware/authMiddleware.js";
import { revokeRefreshToken } from "../services/token.service.js";

const router = express.Router();

/**
 * Firebase Authentication Routes
 * All authentication is handled by Firebase on the client side.
 * These endpoints verify Firebase tokens and sync users to our database.
 */

// Verify Firebase ID token and create/update user in database
// Returns our JWT tokens for API authentication
router.post("/firebase/verify", verifyFirebaseToken);

// Request email verification (triggers Firebase to send verification email)
router.post("/firebase/request-email-verification", requestEmailVerification);

// Logout - revoke refresh token
router.post("/logout", async (req, res) => {
    try {
        const refreshToken = req.body?.refreshToken || req.headers["x-refresh-token"];
        if (refreshToken) {
            await revokeRefreshToken(refreshToken);
        }
        res.json({ message: "Logged out successfully" });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Refresh session - get new access token using refresh token
router.post("/refresh", async (req, res) => {
    try {
        const { verifyRefreshToken: verifyRT, generateAuthTokens } = await import("../services/token.service.js");
        const { findById } = await import("../repositories/user.repository.js");

        const incomingToken = req.body?.refreshToken || req.headers["x-refresh-token"];
        if (!incomingToken) {
            return res.status(400).json({ message: "refreshToken is required" });
        }

        const verified = await verifyRT(incomingToken);
        if (!verified) {
            return res.status(401).json({ message: "Invalid refresh token" });
        }

        const user = await findById(verified.id);
        if (!user) {
            return res.status(404).json({ message: "User not found" });
        }

        const tokens = await generateAuthTokens(user, {
            userAgent: req.get("user-agent"),
            ipAddress: req.ip,
        });

        res.json({
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: tokens.expiresIn,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                avatar_url: user.avatar_url,
                firebase_uid: user.firebase_uid,
                email_verified: user.email_verified,
            },
        });
    } catch (err) {
        res.status(401).json({ message: err.message || "Invalid refresh token" });
    }
});

// Protected route to get current user info
router.get("/me", protect, async (req, res) => {
    try {
        const { findById } = await import("../repositories/user.repository.js");
        const user = await findById(req.user.id);
        if (!user) {
            return res.status(404).json({ message: "User not found" });
        }
        res.json({
            id: user.id,
            email: user.email,
            name: user.name,
            avatar_url: user.avatar_url,
            firebase_uid: user.firebase_uid,
            email_verified: user.email_verified,
            auth_provider: user.auth_provider,
            created_at: user.created_at,
        });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

export default router;
