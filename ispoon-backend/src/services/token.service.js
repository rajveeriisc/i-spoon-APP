import jwt from "jsonwebtoken";
import crypto from "crypto";
import * as tokenRepository from "../repositories/token.repository.js";
import { AppError } from "../utils/errors.js";
import { SECURITY_CONFIG } from "../config/security.js";

const ACCESS_TOKEN_SECRET = process.env.JWT_SECRET || "your-secret-key";
const REFRESH_TOKEN_SECRET = process.env.JWT_REFRESH_SECRET || "your-refresh-secret";
const ACCESS_TOKEN_EXPIRY = process.env.JWT_EXPIRY || SECURITY_CONFIG.JWT.ACCESS_EXPIRES_IN || "7d";
const REFRESH_TOKEN_EXPIRY = SECURITY_CONFIG.JWT.REFRESH_EXPIRES_IN || "30d";

/**
 * Generate access and refresh tokens for a user
 * @param {Object} user - User object
 * @param {Object} context - Request context (IP, user agent)
 * @returns {Promise<Object>} Access and refresh tokens
 */
export const generateAuthTokens = async (user, context = {}) => {
  // Generate access token (short-lived)
  const accessToken = jwt.sign(
    {
      id: user.id,           // Changed from userId to id
      email: user.email,
      type: "access",
    },
    ACCESS_TOKEN_SECRET,
    {
      algorithm: 'HS256',                      // Explicitly specify algorithm
      expiresIn: ACCESS_TOKEN_EXPIRY,
      issuer: SECURITY_CONFIG.JWT.ISSUER,      // Added issuer
      audience: SECURITY_CONFIG.JWT.AUDIENCE,  // Added audience
    }
  );

  // Generate refresh token (long-lived)
  const refreshTokenValue = crypto.randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

  // Store refresh token in database
  await tokenRepository.createRefreshToken({
    userId: user.id,
    token: refreshTokenValue,
    expiresAt,
    ipAddress: context.ipAddress,
    userAgent: context.userAgent,
  });

  const refreshToken = jwt.sign(
    {
      id: user.id,           // Changed from userId to id
      tokenValue: refreshTokenValue,
      type: "refresh",
    },
    REFRESH_TOKEN_SECRET,
    {
      algorithm: 'HS256',                      // Explicitly specify algorithm
      expiresIn: REFRESH_TOKEN_EXPIRY,
      issuer: SECURITY_CONFIG.JWT.ISSUER,
      audience: SECURITY_CONFIG.JWT.AUDIENCE,
    }
  );

  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TOKEN_EXPIRY,
  };
};

/**
 * Verify access token
 * @param {string} token - JWT access token
 * @returns {Object} Decoded token payload
 */
export const verifyAccessToken = (token) => {
  try {
    const decoded = jwt.verify(token, ACCESS_TOKEN_SECRET);
    if (decoded.type !== "access") {
      throw new AppError("Invalid token type", 401);
    }
    return decoded;
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      throw new AppError("Token expired", 401);
    }
    if (error.name === "JsonWebTokenError") {
      throw new AppError("Invalid token", 401);
    }
    throw error;
  }
};

/**
 * Verify refresh token
 * @param {string} token - JWT refresh token
 * @returns {Promise<Object>} Decoded token payload
 */
export const verifyRefreshToken = async (token) => {
  try {
    const decoded = jwt.verify(token, REFRESH_TOKEN_SECRET);
    if (decoded.type !== "refresh") {
      throw new AppError("Invalid token type", 401);
    }

    // Check if token exists and is not revoked
    const storedToken = await tokenRepository.findRefreshToken(
      decoded.id,
      decoded.tokenValue
    );

    if (!storedToken || storedToken.revoked) {
      throw new AppError("Token revoked or invalid", 401);
    }

    if (new Date() > new Date(storedToken.expires_at)) {
      throw new AppError("Token expired", 401);
    }

    return decoded;
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      throw new AppError("Refresh token expired", 401);
    }
    if (error.name === "JsonWebTokenError") {
      throw new AppError("Invalid refresh token", 401);
    }
    throw error;
  }
};

/**
 * Revoke a refresh token
 * @param {string} token - JWT refresh token
 */
export const revokeRefreshToken = async (token) => {
  try {
    const decoded = jwt.verify(token, REFRESH_TOKEN_SECRET);
    await tokenRepository.revokeRefreshToken(decoded.id, decoded.tokenValue);
  } catch (error) {
    // Silent fail for logout
  }
};

/**
 * Revoke all refresh tokens for a user
 * @param {number} userId - User ID
 */
export const revokeAllUserTokens = async (userId) => {
  await tokenRepository.revokeAllUserTokens(userId);
};

/**
 * Clean up expired tokens
 */
export const cleanupExpiredTokens = async () => {
  await tokenRepository.deleteExpiredTokens();
};

