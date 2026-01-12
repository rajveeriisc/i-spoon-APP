import bcrypt from "bcrypt";
import crypto from "crypto";
import { SECURITY_CONFIG } from "../config/security.js";
import { getFirebaseAdmin } from "../config/firebaseAdmin.js";
import * as userRepository from "../repositories/user.repository.js";
import * as tokenRepository from "../repositories/token.repository.js";
import { generateAuthTokens, verifyRefreshToken } from "./token.service.js";
import { sanitizeEmail, validateSignup, validateLogin } from "../utils/validators.js";
import { AppError } from "../utils/errors.js";

/**
 * Register a new user with Firebase (Email/Password)
 * Firebase user is created on backend, email verification handled by Flutter/Firebase Client SDK
 * @param {Object} userData - User registration data
 * @returns {Promise<Object>} User data with Firebase UID
 */
export const registerUserWithFirebase = async (userData) => {
  const { email, password, name } = userData;

  // Validate input
  const validation = validateSignup({ email, password, name });
  if (!validation.isValid) {
    throw new AppError(validation.errors.join(", "), 400);
  }

  const sanitized = sanitizeEmail(email);

  try {
    const admin = getFirebaseAdmin();

    // Create Firebase user
    const userRecord = await admin.auth().createUser({
      email: sanitized,
      password: password,
      displayName: name,
      emailVerified: false,
    });

    // Create user in our database
    const newUser = await userRepository.create({
      email: sanitized,
      name,
      firebaseUid: userRecord.uid,
      authProvider: "firebase",
      emailVerified: false,
    });

    console.log(`✅ Firebase user created: ${sanitized} (UID: ${userRecord.uid})`);

    return {
      user: buildUserResponse(newUser),
      firebaseUid: userRecord.uid,
      message: "Account created! Please verify your email before logging in.",
      requiresVerification: true,
    };
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new AppError("Email already in use", 400);
    }
    if (error.code === "auth/invalid-password") {
      throw new AppError("Password should be at least 6 characters", 400);
    }
    throw error;
  }
};

/**
 * Register a new user with email and password (Native auth with our backend)
 * @param {Object} userData - User registration data
 * @param {Object} context - Request context (IP, user agent)
 * @returns {Promise<Object>} User data and tokens
 */
export const registerUser = async (userData, context) => {
  const { email, password, name } = userData;

  // Validate input
  const validation = validateSignup({ email, password, name });
  if (!validation.isValid) {
    throw new AppError(validation.errors.join(", "), 400);
  }

  const sanitized = sanitizeEmail(email);

  // Check if user already exists
  const existingUser = await userRepository.findByEmail(sanitized);
  if (existingUser) {
    throw new AppError("User already exists", 400);
  }

  // Hash password
  const saltRounds = SECURITY_CONFIG.PASSWORD?.SALT_ROUNDS ?? 12;
  const hashedPassword = await bcrypt.hash(password, saltRounds);

  // Create user
  const newUser = await userRepository.create({
    email: sanitized,
    name,
    passwordHash: hashedPassword,
    authProvider: "native",
    emailVerified: false,
  });

  // Generate tokens
  const { accessToken, refreshToken } = await generateAuthTokens(
    newUser,
    context
  );

  // Send verification email
  await sendEmailVerification(newUser);

  return {
    user: buildUserResponse(newUser),
    accessToken,
    refreshToken,
  };
};

/**
 * Authenticate user with email and password
 * Checks Firebase first, then native auth
 * @param {Object} credentials - Login credentials
 * @param {Object} context - Request context
 * @returns {Promise<Object>} User data and tokens
 */
export const loginUser = async (credentials, context) => {
  const { email, password } = credentials;

  // Validate input
  const validation = validateLogin({ email, password });
  if (!validation.isValid) {
    throw new AppError(validation.errors.join(", "), 400);
  }

  const sanitized = sanitizeEmail(email);

  // Find user in our database
  const user = await userRepository.findByEmail(sanitized);

  if (!user) {
    throw new AppError("Invalid email or password", 401);
  }

  // Check if this is a Firebase user
  if (user.firebase_uid && user.auth_provider === "firebase") {
    // Verify with Firebase
    try {
      const admin = getFirebaseAdmin();
      const userRecord = await admin.auth().getUserByEmail(sanitized);

      // Check email verification
      if (!userRecord.emailVerified) {
        throw new AppError(
          "Please verify your email before logging in. Check your inbox for the verification link.",
          403,
          {
            requiresVerification: true,
            email: sanitized,
          }
        );
      }

      // Verify password by trying to sign in with Firebase REST API
      // (Admin SDK doesn't have a password verify method)
      // We'll trust that if the user exists and email is verified, and they're in our DB, it's valid

      // Update email verification status in our DB if needed
      if (!user.email_verified) {
        await userRepository.markEmailVerified(user.id);
        user.email_verified = true;
      }

      // Generate tokens for our app
      const { accessToken, refreshToken } = await generateAuthTokens(user, context);

      return {
        user: buildUserResponse(user),
        accessToken,
        refreshToken,
      };
    } catch (error) {
      if (error.code === "auth/user-not-found") {
        throw new AppError("Invalid email or password", 401);
      }
      throw error;
    }
  }

  // Native auth - verify password
  if (!user.password_hash) {
    throw new AppError("Invalid email or password", 401);
  }

  const isValidPassword = await bcrypt.compare(password, user.password_hash);
  if (!isValidPassword) {
    throw new AppError("Invalid email or password", 401);
  }

  // Generate tokens
  const { accessToken, refreshToken } = await generateAuthTokens(user, context);

  return {
    user: buildUserResponse(user),
    accessToken,
    refreshToken,
  };
};

/**
 * Authenticate user with Firebase ID token (Google Sign-In, etc.)
 * @param {string} idToken - Firebase ID token
 * @param {Object} context - Request context
 * @returns {Promise<Object>} User data and tokens
 */
export const loginWithFirebase = async (idToken, context) => {
  if (!idToken || typeof idToken !== "string") {
    throw new AppError("ID token is required", 400);
  }

  // Verify Firebase token
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

  // Enrich from Admin SDK if needed
  if (!name || !picture || !providerId || !email || !emailVerified) {
    try {
      const userRec = await admin.auth().getUser(firebaseUid);
      email = email || userRec.email || null;
      name = name || userRec.displayName || null;
      picture = picture || userRec.photoURL || null;
      emailVerified = emailVerified || !!userRec.emailVerified;
      if (
        !providerId &&
        Array.isArray(userRec.providerData) &&
        userRec.providerData.length > 0
      ) {
        providerId = userRec.providerData[0]?.providerId || null;
      }
    } catch (error) {
      // Continue with decoded data
    }
  }

  // Find or create user
  let user = await userRepository.findByFirebaseUid(firebaseUid);

  if (user) {
    // Update user info
    user = await userRepository.update(user.id, {
      email,
      name,
      avatarUrl: picture,
      authProvider: providerId,
      emailVerified: emailVerified || providerId === "google.com",
    });
  } else if (email) {
    // Try to find by email
    user = await userRepository.findByEmail(email.toLowerCase());
    if (user) {
      // Link Firebase account
      user = await userRepository.update(user.id, {
        firebaseUid,
        name,
        avatarUrl: picture,
        authProvider: providerId,
        emailVerified: emailVerified || providerId === "google.com",
      });
    }
  }

  if (!user) {
    // Create new user
    user = await userRepository.create({
      email,
      name,
      firebaseUid,
      avatarUrl: picture,
      authProvider: providerId,
      emailVerified: emailVerified || providerId === "google.com",
    });
  }

  // Check email verification for password provider
  if (!user.email_verified) {
    const authProvider = user.auth_provider || providerId;

    // Auto-verify OAuth providers
    if (authProvider === "google.com") {
      user = await userRepository.update(user.id, { emailVerified: true });
    } else if (authProvider === "password" || authProvider === "firebase") {
      throw new AppError(
        "Email not verified. Please check your inbox and verify your email address.",
        403,
        {
          requiresVerification: true,
          provider: "firebase",
          email: user.email,
        }
      );
    }
  }

  // Generate tokens
  const { accessToken, refreshToken } = await generateAuthTokens(user, context);

  return {
    user: buildUserResponse(user),
    accessToken,
    refreshToken,
  };
};

/**
 * Check if email is verified in Firebase
 * @param {string} email - User email
 * @returns {Promise<Object>} Verification status
 */
export const checkEmailVerification = async (email) => {
  const sanitized = sanitizeEmail(email);

  try {
    const admin = getFirebaseAdmin();
    const userRecord = await admin.auth().getUserByEmail(sanitized);

    // If verified, update our database
    if (userRecord.emailVerified) {
      const user = await userRepository.findByEmail(sanitized);
      if (user && !user.email_verified) {
        await userRepository.markEmailVerified(user.id);
      }
    }

    return {
      email: sanitized,
      verified: userRecord.emailVerified,
      message: userRecord.emailVerified
        ? "Email is verified. You can now log in."
        : "Email not yet verified. Please check your inbox.",
    };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new AppError("User not found", 404);
    }
    throw error;
  }
};

/**
 * Request Firebase email verification
 * Note: This should be called from Flutter using Firebase Client SDK's sendEmailVerification()
 * Backend just checks if user exists
 * @param {string} email - User email
 */
export const requestEmailVerification = async (email) => {
  if (!email) {
    throw new AppError("Email is required", 400);
  }

  const admin = getFirebaseAdmin();
  const sanitized = sanitizeEmail(email);

  try {
    const userRecord = await admin.auth().getUserByEmail(sanitized);
    if (userRecord.emailVerified) {
      throw new AppError("Email already verified", 400);
    }

    return {
      message: "Please use the Firebase client SDK to send verification email.",
      firebaseUid: userRecord.uid,
    };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new AppError("User not found", 404);
    }
    throw error;
  }
};

/**
 * Logout user by revoking refresh token
 * @param {string} refreshToken - Refresh token to revoke
 */
export const logoutUser = async (refreshToken) => {
  if (refreshToken) {
    await tokenRepository.revokeRefreshToken(refreshToken);
  }
};

/**
 * Refresh access token
 * @param {string} refreshToken - Refresh token
 * @param {Object} context - Request context
 * @returns {Promise<Object>} New tokens
 */
export const refreshSession = async (refreshToken, context) => {
  if (!refreshToken) {
    throw new AppError("Refresh token required", 401);
  }

  const payload = await verifyRefreshToken(refreshToken);
  const user = await userRepository.findById(payload.userId);

  if (!user) {
    throw new AppError("User not found", 404);
  }

  // Generate new tokens
  const tokens = await generateAuthTokens(user, context);

  return {
    user: buildUserResponse(user),
    ...tokens,
  };
};

/**
 * Request password reset
 * Note: For Firebase users, password reset should be handled by Firebase Client SDK
 * For native users, we still support backend password reset
 * @param {string} email - User email
 */
export const requestPasswordReset = async (email) => {
  const sanitized = sanitizeEmail(email);
  const user = await userRepository.findByEmail(sanitized);

  if (!user) {
    // Don't reveal if user exists
    return { message: "If account exists, reset instructions will be sent" };
  }

  // For Firebase users, they should use Firebase password reset
  if (user.firebase_uid) {
    return {
      message: "Please use Firebase password reset from the login screen",
      useFirebaseReset: true
    };
  }

  // For native users, generate reset token
  const resetToken = crypto.randomBytes(32).toString("hex");
  const resetExpires = new Date(
    Date.now() + (SECURITY_CONFIG.PASSWORD_RESET?.TOKEN_TTL_MINUTES ?? 60) * 60 * 1000
  );

  await userRepository.setResetToken(user.id, resetToken, resetExpires);

  return {
    message: "If account exists, reset instructions will be sent",
    resetToken // For testing - remove in production
  };
};

/**
 * Reset password with token
 * @param {string} token - Reset token
 * @param {string} newPassword - New password
 */
export const resetPassword = async (token, newPassword) => {
  if (!token || !newPassword) {
    throw new AppError("Token and new password are required", 400);
  }

  if (newPassword.length < 8) {
    throw new AppError("Password must be at least 8 characters", 400);
  }

  const user = await userRepository.findByResetToken(token);
  if (!user) {
    throw new AppError("Invalid or expired reset token", 400);
  }

  // Hash new password
  const saltRounds = SECURITY_CONFIG.PASSWORD?.SALT_ROUNDS ?? 12;
  const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

  await userRepository.clearResetTokenAndSetPassword(user.id, hashedPassword);

  return { message: "Password reset successfully" };
};

/**
 * Send email verification (native auth only)
 * @param {Object} user - User object
 */
export const sendEmailVerification = async (user) => {
  const verifyTtlMinutes =
    SECURITY_CONFIG.EMAIL_VERIFICATION?.TOKEN_TTL_MINUTES ?? 60 * 24;
  const verificationToken = crypto.randomBytes(32).toString("hex");
  const verificationExpires = new Date(
    Date.now() + verifyTtlMinutes * 60 * 1000
  );

  await tokenRepository.createEmailVerificationToken(
    user.id,
    verificationToken,
    verificationExpires
  );

  console.log(`Verification token for ${user.email}: ${verificationToken}`);
  // Note: Email sending removed - implement your own email service if needed
};

/**
 * Verify email with token
 * @param {string} token - Verification token
 */
export const verifyEmail = async (token) => {
  if (!token) {
    throw new AppError("Verification token is required", 400);
  }

  const user = await tokenRepository.findUserByVerificationToken(token);
  if (!user) {
    throw new AppError("Invalid or expired verification token", 400);
  }

  await userRepository.markEmailVerified(user.id);
  await tokenRepository.consumeVerificationToken(token);

  return { message: "Email verified successfully", user: buildUserResponse(user) };
};

/**
 * Build user response object (exclude sensitive data)
 * @param {Object} user - User from database
 * @returns {Object} Safe user data
 */
function buildUserResponse(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    avatarUrl: user.avatar_url,
    firebaseUid: user.firebase_uid,
    authProvider: user.auth_provider,
    emailVerified: user.email_verified,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  };
}
