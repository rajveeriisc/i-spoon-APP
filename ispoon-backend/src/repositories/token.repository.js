import crypto from "crypto";
import { pool } from "../config/db.js";

/**
 * Hash token for secure storage
 * @param {string} token - Plain text token
 * @returns {string} Hashed token
 */
const hashToken = (token) => {
  return crypto.createHash("sha256").update(token).digest("hex");
};

// ========== Refresh Tokens ==========

/**
 * Create a refresh token
 * @param {Object} tokenData - Token data
 * @returns {Promise<Object>} Created token
 */
export const createRefreshToken = async (tokenData) => {
  const { userId, token, expiresAt, userAgent = null, ipAddress = null } = tokenData;
  const tokenHash = hashToken(token);

  const res = await pool.query(
    `INSERT INTO refresh_tokens (
      user_id, token_hash, expires_at, user_agent, ip_address, created_at
    ) 
    VALUES ($1, $2, $3, $4, $5, NOW()) 
    RETURNING *`,
    [userId, tokenHash, expiresAt, userAgent, ipAddress]
  );

  return res.rows[0];
};

/**
 * Find refresh token
 * @param {number} userId - User ID
 * @param {string} token - Token value
 * @returns {Promise<Object|null>} Token or null
 */
export const findRefreshToken = async (userId, token) => {
  const tokenHash = hashToken(token);
  const res = await pool.query(
    `SELECT * FROM refresh_tokens 
     WHERE user_id = $1 AND token_hash = $2 
     LIMIT 1`,
    [userId, tokenHash]
  );
  return res.rows[0] || null;
};

/**
 * Revoke a refresh token
 * @param {number} userId - User ID
 * @param {string} token - Token value
 */
export const revokeRefreshToken = async (userId, token) => {
  const tokenHash = hashToken(token);
  await pool.query(
    `UPDATE refresh_tokens 
     SET revoked_at = NOW() 
     WHERE user_id = $1 AND token_hash = $2 AND revoked_at IS NULL`,
    [userId, tokenHash]
  );
};

/**
 * Revoke all refresh tokens for a user
 * @param {number} userId - User ID
 */
export const revokeAllUserTokens = async (userId) => {
  await pool.query(
    `UPDATE refresh_tokens 
     SET revoked_at = NOW() 
     WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId]
  );
};

/**
 * Delete expired tokens
 */
export const deleteExpiredTokens = async () => {
  await pool.query(
    `DELETE FROM refresh_tokens 
     WHERE expires_at < NOW() OR revoked_at < NOW() - INTERVAL '30 days'`
  );
};

// ========== Email Verification Tokens ==========

/**
 * Create email verification token
 * @param {number} userId - User ID
 * @param {string} token - Token value
 * @param {Date} expiresAt - Expiration date
 * @returns {Promise<Object>} Created token
 */
export const createEmailVerificationToken = async (userId, token, expiresAt) => {
  const tokenHash = hashToken(token);

  // Delete any existing verification tokens for this user
  await pool.query(
    "DELETE FROM email_verification_tokens WHERE user_id = $1",
    [userId]
  );

  const res = await pool.query(
    `INSERT INTO email_verification_tokens (
      user_id, token_hash, token_expires_at, created_at
    ) 
    VALUES ($1, $2, $3, NOW()) 
    RETURNING *`,
    [userId, tokenHash, expiresAt]
  );

  return res.rows[0];
};

/**
 * Find user by verification token
 * @param {string} token - Token value
 * @returns {Promise<Object|null>} User data or null
 */
export const findUserByVerificationToken = async (token) => {
  const tokenHash = hashToken(token);
  const res = await pool.query(
    `SELECT 
      evt.id as token_id,
      evt.user_id,
      evt.token_expires_at,
      evt.consumed_at,
      u.id,
      u.email,
      u.name,
      u.email_verified
    FROM email_verification_tokens evt
    JOIN users u ON u.id = evt.user_id
    WHERE evt.token_hash = $1 
      AND evt.consumed_at IS NULL 
      AND evt.token_expires_at > NOW()
    LIMIT 1`,
    [tokenHash]
  );
  return res.rows[0] || null;
};

/**
 * Consume (mark as used) a verification token
 * @param {string} token - Token value
 */
export const consumeVerificationToken = async (token) => {
  const tokenHash = hashToken(token);
  await pool.query(
    `UPDATE email_verification_tokens 
     SET consumed_at = NOW() 
     WHERE token_hash = $1 AND consumed_at IS NULL`,
    [tokenHash]
  );
};

/**
 * Delete verification tokens for a user
 * @param {number} userId - User ID
 */
export const deleteVerificationTokensForUser = async (userId) => {
  await pool.query(
    "DELETE FROM email_verification_tokens WHERE user_id = $1",
    [userId]
  );
};

