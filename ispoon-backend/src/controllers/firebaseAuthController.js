import { pool } from "../config/db.js";
import {
  getFirebaseAdmin,
  generateFirebaseVerificationLink
} from "../config/firebaseAdmin.js";
import { generateAuthTokens } from "../services/token.service.js";
import { sendWelcomeEmail } from "../services/email.service.js";

/**
 * Verify Firebase ID Token and Create/Update User in Database
 * 
 * AUTH FLOW:
 * 1. Flutter App calls POST /api/auth/firebase/verify with Firebase idToken
 * 2. This function verifies the token with Firebase Admin SDK
 * 3. Extracts user info: uid, email, name, picture, providerId, emailVerified
 * 4. Upserts user in PostgreSQL (finds by firebase_uid or email, or creates new)
 * 5. For email/password auth: requires emailVerified = true (returns 403 if not)
 * 6. For Google OAuth: auto-marks as verified
 * 7. Generates backend JWT tokens (accessToken + refreshToken)
 * 8. Returns { token, tokens, user } to Flutter app
 * 
 * CALLED BY: Flutter auth_service.dart → verifyFirebaseToken()
 * NEXT STEP: Flutter stores tokens in SecureStorage → navigates to HomePage
 * 
 * @param {Request} req - Express request with body.idToken
 * @param {Response} res - Express response
 */
export const verifyFirebaseToken = async (req, res) => {
  try {
    const { idToken } = req.body || {};
    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({ message: "idToken is required" });
    }

    const admin = getFirebaseAdmin();
    const decoded = await admin.auth().verifyIdToken(idToken);

    const firebaseUid = decoded.uid;
    let email = decoded.email || null;
    let name = decoded.name || null;
    let picture = decoded.picture || null;
    let providerId = Array.isArray(decoded.firebase?.sign_in_provider)
      ? decoded.firebase.sign_in_provider[0]
      : decoded.firebase?.sign_in_provider || null;
    let emailVerified = !!decoded.email_verified;

    // Enrich from Admin SDK if claims are missing (common for email/password right after signup)
    if (!name || !picture || !providerId || !email || !emailVerified) {
      try {
        const userRec = await admin.auth().getUser(firebaseUid);
        email = email || userRec.email || null;
        name = name || userRec.displayName || null;
        picture = picture || userRec.photoURL || null;
        emailVerified = emailVerified || !!userRec.emailVerified;
        if (!providerId && Array.isArray(userRec.providerData) && userRec.providerData.length > 0) {
          providerId = userRec.providerData[0]?.providerId || null;
        }
      } catch (_) { }
    }

    // Force email to lowercase to ensure consistent linking
    if (email) {
      email = email.toLowerCase();
    }

    // Upsert user in Postgres
    let userRow = null;
    // Try by firebase_uid first
    const byUid = await pool.query("SELECT * FROM users WHERE firebase_uid = $1", [firebaseUid]);
    if (byUid.rows.length > 0) {
      userRow = byUid.rows[0];
      // Update basic profile if changed
      await pool.query(
        `UPDATE users SET email = COALESCE($1, email), name = COALESCE($2, name), avatar_url = COALESCE($3, avatar_url), auth_provider = COALESCE($4, auth_provider), email_verified = $5, updated_at = NOW() WHERE id = $6`,
        [email, name, picture, providerId, emailVerified, userRow.id]
      );
      const refreshed = await pool.query("SELECT * FROM users WHERE id = $1", [userRow.id]);
      userRow = refreshed.rows[0];
    } else if (email) {
      // fallback: try by email
      const byEmail = await pool.query("SELECT * FROM users WHERE email = $1", [email.toLowerCase()]);
      if (byEmail.rows.length > 0) {
        userRow = byEmail.rows[0];
        await pool.query(
          `UPDATE users SET firebase_uid = $1, name = COALESCE($2, name), avatar_url = COALESCE($3, avatar_url), auth_provider = COALESCE($4, auth_provider), email_verified = $5, updated_at = NOW() WHERE id = $6`,
          [firebaseUid, name, picture, providerId, emailVerified, userRow.id]
        );
        const refreshed = await pool.query("SELECT * FROM users WHERE id = $1", [userRow.id]);
        userRow = refreshed.rows[0];
      }
    }

    if (!userRow) {
      const inserted = await pool.query(
        `INSERT INTO users (email, name, firebase_uid, avatar_url, auth_provider, email_verified, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW()) RETURNING *`,
        [email, name, firebaseUid, picture, providerId, emailVerified]
      );
      userRow = inserted.rows[0];
    }

    // Handle email verification based on auth provider
    // Check Firebase verification status first (fresh from Firebase, not DB)
    const authProvider = userRow.auth_provider || providerId;

    if (authProvider === 'google.com') {
      // Google OAuth users are automatically verified by Google
      if (!userRow.email_verified) {
        await pool.query(
          'UPDATE users SET email_verified = true, updated_at = NOW() WHERE id = $1',
          [userRow.id]
        );
        userRow.email_verified = true;
      }
    } else if (authProvider === 'password') {
      // For Firebase email/password, use the FRESH emailVerified status from Firebase
      // (not the stale DB value)
      if (!emailVerified) {
        return res.status(403).json({
          message: "Email not verified. Please check your inbox and verify your email address.",
          requiresVerification: true,
          provider: 'firebase',
          email: userRow.email,
        });
      }

      // Sync the verification status to DB if it changed
      if (emailVerified && !userRow.email_verified) {
        await pool.query(
          'UPDATE users SET email_verified = true, updated_at = NOW() WHERE id = $1',
          [userRow.id]
        );
        userRow.email_verified = true;
      }
    } else if (!userRow.email_verified) {
      // Other OAuth providers
      return res.status(403).json({
        message: "Email not verified. Please verify your email with your authentication provider.",
        requiresVerification: true,
        provider: authProvider,
      });
    }

    // ✨ SEND WELCOME EMAIL - Trigger after email verification
    // Only send if user is verified AND welcome email hasn't been sent yet
    if (userRow.email_verified && !userRow.welcome_email_sent) {
      try {
        console.log(`📧 Sending welcome email to ${userRow.email}...`);
        await sendWelcomeEmail({
          email: userRow.email,
          name: userRow.name,
        });

        // Mark welcome email as sent in database
        await pool.query(
          'UPDATE users SET welcome_email_sent = true, welcome_email_sent_at = NOW(), updated_at = NOW() WHERE id = $1',
          [userRow.id]
        );

        console.log(`✅ Welcome email sent successfully to ${userRow.email}`);
      } catch (emailError) {
        // Log error but don't block user login if email fails
        console.error(`❌ Failed to send welcome email to ${userRow.email}:`, emailError);
        // Continue with login even if email fails
      }
    }

    const tokens = await generateAuthTokens(userRow, {
      userAgent: req.get("user-agent"),
      ipAddress: req.ip,
    });

    return res.json({
      token: tokens.accessToken,
      tokens,
      user: {
        id: userRow.id,
        email: userRow.email,
        name: userRow.name,
        avatar_url: userRow.avatar_url,
        firebase_uid: userRow.firebase_uid,
        auth_provider: userRow.auth_provider,
        email_verified: userRow.email_verified,
        created_at: userRow.created_at,
      },
    });
  } catch (err) {
    console.error("verifyFirebaseToken error:", err);
    const msg = String(err?.message || "");
    const isAuth = /id token|auth|credential|parse private key|pem/i.test(msg);
    const status = isAuth ? 401 : 500;
    return res.status(status).json({
      message: isAuth ? "Invalid Firebase ID token" : "Internal error",
      error: process.env.NODE_ENV === 'development' ? msg : undefined
    });
  }
};

/**
 * Request Email Verification for Firebase Users
 * 
 * Sends a verification email to users who signed up with email/password.
 * This endpoint triggers Firebase to send the verification email directly.
 * 
 * AUTH FLOW:
 * 1. Flutter App calls POST /api/auth/firebase/request-email-verification with idToken
 * 2. This function verifies the token with Firebase Admin SDK
 * 3. Checks if email is already verified (returns 400 if yes)
 * 4. Generates Firebase verification link via Admin SDK
 * 5. Firebase sends verification email to user
 * 6. Returns success message to Flutter app
 * 
 * CALLED BY: Flutter login_screen.dart → _sendEmailVerificationLink()
 *            (via firebase_auth_service.dart → sendEmailVerificationLink())
 * 
 * @param {Request} req - Express request with body.idToken
 * @param {Response} res - Express response
 */
export const requestEmailVerification = async (req, res) => {
  try {
    const { idToken } = req.body || {};

    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({ message: "idToken is required" });
    }

    const admin = getFirebaseAdmin();
    const decoded = await admin.auth().verifyIdToken(idToken);

    // Check if already verified
    if (decoded.email_verified) {
      return res.status(400).json({
        message: "Email is already verified",
        verified: true
      });
    }

    const email = decoded.email;
    if (!email) {
      return res.status(400).json({
        message: "No email associated with this account"
      });
    }

    // Generate verification link using Firebase Admin SDK
    try {
      const verificationLink = await generateFirebaseVerificationLink(email);

      // Firebase handles sending the verification email directly
      // No additional email service needed

      return res.json({
        message: "Verification email sent. Please check your inbox.",
        email: email,
        sent: true
      });
    } catch (linkError) {
      console.error("Failed to generate verification link:", linkError);
      return res.status(500).json({
        message: "Failed to send verification email. Please try again later."
      });
    }
  } catch (err) {
    console.error("requestEmailVerification error:", err);

    const msg = String(err?.message || "");
    const isAuth = /id token|auth|credential|parse private key|pem/i.test(msg);
    const status = isAuth ? 401 : 500;

    return res.status(status).json({
      message: isAuth ? "Invalid Firebase ID token" : "Internal error",
      error: process.env.NODE_ENV === 'development' ? msg : undefined
    });
  }
};

