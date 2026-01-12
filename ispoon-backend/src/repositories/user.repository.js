import { pool } from "../config/db.js";
import crypto from "crypto";

/**
 * Create a new user
 * @param {Object} userData - User data
 * @returns {Promise<Object>} Created user
 */
export const create = async (userData) => {
  const {
    email,
    name = null,
    passwordHash = null,
    firebaseUid = null,
    avatarUrl = null,
    authProvider = "native",
    emailVerified = false,
  } = userData;

  const normalizedEmail = email.toLowerCase();

  const res = await pool.query(
    `INSERT INTO users (
      email, password, name, firebase_uid, avatar_url, 
      auth_provider, email_verified, created_at, updated_at
    ) 
    VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) 
    RETURNING *`,
    [normalizedEmail, passwordHash, name, firebaseUid, avatarUrl, authProvider, emailVerified]
  );

  return res.rows[0];
};

/**
 * Find user by email
 * @param {string} email - User email
 * @returns {Promise<Object|null>} User or null
 */
export const findByEmail = async (email) => {
  const normalizedEmail = email.toLowerCase();
  const res = await pool.query(
    "SELECT * FROM users WHERE email = $1",
    [normalizedEmail]
  );
  return res.rows[0] || null;
};

/**
 * Find user by ID
 * @param {number} id - User ID
 * @returns {Promise<Object|null>} User or null
 */
export const findById = async (id) => {
  const res = await pool.query(
    "SELECT * FROM users WHERE id = $1",
    [id]
  );
  return res.rows[0] || null;
};

/**
 * Find user by Firebase UID
 * @param {string} firebaseUid - Firebase UID
 * @returns {Promise<Object|null>} User or null
 */
export const findByFirebaseUid = async (firebaseUid) => {
  const res = await pool.query(
    "SELECT * FROM users WHERE firebase_uid = $1",
    [firebaseUid]
  );
  return res.rows[0] || null;
};

/**
 * Update user
 * @param {number} id - User ID
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Updated user
 */
export const update = async (id, updates) => {
  const allowed = [
    "email",
    "name",
    "phone",
    "location",
    "bio",
    "diet_type",
    "activity_level",
    "allergies",
    "daily_goal",
    "notifications_enabled",
    "emergency_contact",
    "avatar_url",
    "firebase_uid",
    "auth_provider",
    "email_verified",
  ];

  const setClauses = [];
  const values = [];
  let paramIndex = 1;

  // Map camelCase to snake_case
  const fieldMapping = {
    avatarUrl: "avatar_url",
    firebaseUid: "firebase_uid",
    authProvider: "auth_provider",
    emailVerified: "email_verified",
    dietType: "diet_type",
    activityLevel: "activity_level",
    dailyGoal: "daily_goal",
    notificationsEnabled: "notifications_enabled",
    emergencyContact: "emergency_contact",
  };

  for (const [key, value] of Object.entries(updates)) {
    const dbField = fieldMapping[key] || key;

    if (allowed.includes(dbField)) {
      setClauses.push(`${dbField} = $${paramIndex++}`);
      values.push(value);
    }
  }

  if (setClauses.length === 0) {
    return findById(id);
  }

  setClauses.push(`updated_at = NOW()`);

  const query = `
    UPDATE users 
    SET ${setClauses.join(", ")} 
    WHERE id = $${paramIndex} 
    RETURNING *
  `;
  values.push(id);

  const res = await pool.query(query, values);
  return res.rows[0];
};

/**
 * Set password reset token
 * @param {number} userId - User ID
 * @param {string} token - Reset token
 * @param {Date} expiresAt - Expiration date
 */
export const setResetToken = async (userId, token, expiresAt) => {
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  await pool.query(
    `UPDATE users 
     SET reset_token = $1, reset_token_expires_at = $2, updated_at = NOW() 
     WHERE id = $3`,
    [tokenHash, expiresAt, userId]
  );
};

/**
 * Find user by reset token
 * @param {string} token - Reset token
 * @returns {Promise<Object|null>} User or null
 */
export const findByResetToken = async (token) => {
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  const res = await pool.query(
    `SELECT * FROM users 
     WHERE reset_token = $1 AND reset_token_expires_at > NOW()`,
    [tokenHash]
  );
  return res.rows[0] || null;
};

/**
 * Clear reset token and set new password
 * @param {number} userId - User ID
 * @param {string} hashedPassword - New hashed password
 */
export const clearResetTokenAndSetPassword = async (userId, hashedPassword) => {
  await pool.query(
    `UPDATE users 
     SET password = $1, reset_token = NULL, reset_token_expires_at = NULL, updated_at = NOW() 
     WHERE id = $2`,
    [hashedPassword, userId]
  );
};

/**
 * Mark user email as verified
 * @param {number} userId - User ID
 */
export const markEmailVerified = async (userId) => {
  await pool.query(
    `UPDATE users 
     SET email_verified = true, updated_at = NOW() 
     WHERE id = $1`,
    [userId]
  );
};

/**
 * Delete user (soft delete could be implemented here)
 * @param {number} userId - User ID
 */
export const deleteUser = async (userId) => {
  await pool.query("DELETE FROM users WHERE id = $1", [userId]);
};

