import jwt from "jsonwebtoken";
import { pool } from "../config/db.js";
import { getFirebaseAdmin } from "../config/firebaseAdmin.js";
import { sendFirebaseVerificationEmail } from "../emails/firebase.js";
import { SECURITY_CONFIG } from "../config/security.js";

// JWT secret - must be set in environment variables
if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required');
}
const JWT_SECRET = process.env.JWT_SECRET;

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
      } catch (_) {}
    }

    // Enforce email verification for password-based accounts
    if (!emailVerified && (providerId === 'password' || providerId === 'firebase' || !providerId)) {
      return res.status(403).json({ message: "Email not verified. Please verify your email to continue." });
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

    // Sign backend JWT with standard claims
    const token = jwt.sign(
      { 
        id: userRow.id, 
        email: userRow.email,
        type: 'access',
        firebase_uid: firebaseUid
      },
      JWT_SECRET,
      { 
        expiresIn: SECURITY_CONFIG.JWT.EXPIRES_IN,
        issuer: SECURITY_CONFIG.JWT.ISSUER,
        audience: SECURITY_CONFIG.JWT.AUDIENCE,
        subject: userRow.id.toString()
      }
    );

    return res.json({
      token,
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
    try { console.error("verifyFirebaseToken error:", err); } catch (_) {}
    const msg = String(err?.message || "");
    const isAuth = /id token|auth|credential|parse private key|pem/i.test(msg);
    const status = isAuth ? 401 : 500;
    return res.status(status).json({ message: isAuth ? "Invalid Firebase ID token" : "Internal error" });
  }
};

export const sendVerification = async (req, res) => {
  try {
    const { idToken } = req.body || {};
    if (!idToken || typeof idToken !== "string") {
      return res.status(400).json({ message: "idToken is required" });
    }
    await sendFirebaseVerificationEmail(idToken);
    return res.json({ message: "Verification email sent" });
  } catch (err) {
    const msg = String(err?.message || "");
    const isAuth = /token|auth|credential|invalid/i.test(msg);
    const status = isAuth ? 401 : 500;
    return res.status(status).json({ message: isAuth ? "Invalid Firebase ID token" : "Internal error" });
  }
};


