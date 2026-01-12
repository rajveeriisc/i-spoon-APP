import path from "path";
import fs from "fs/promises";
import * as userRepository from "../repositories/user.repository.js";
import { AppError } from "../utils/errors.js";
import { sanitizeUserProfile } from "../utils/sanitize.js";

/**
 * Get user by ID
 * @param {number} userId - User ID
 * @returns {Promise<Object>} User data
 */
export const getUserById = async (userId) => {
  const user = await userRepository.findById(userId);
  if (!user) {
    throw new AppError("User not found", 404);
  }
  return buildUserResponse(user);
};

/**
 * Update user profile
 * @param {number} userId - User ID
 * @param {Object} updates - Profile updates
 * @returns {Promise<Object>} Updated user
 */
export const updateUserProfile = async (userId, updates) => {
  // Remove sensitive fields
  delete updates.email;
  delete updates.password;
  delete updates.firebase_uid;

  // Sanitize input
  const sanitized = sanitizeUserProfile(updates);

  const updatedUser = await userRepository.update(userId, sanitized);
  return buildUserResponse(updatedUser);
};

/**
 * Upload user avatar
 * @param {number} userId - User ID
 * @param {Object} fileInfo - Processed file information
 * @returns {Promise<Object>} Updated user
 */
export const uploadUserAvatar = async (userId, fileInfo) => {
  // Get current user to delete old avatar
  const currentUser = await userRepository.findById(userId);
  const oldAvatarUrl = currentUser?.avatar_url;

  // Update avatar URL
  const updatedUser = await userRepository.update(userId, {
    avatarUrl: fileInfo.url,
  });

  // Delete old avatar file (async, non-blocking)
  if (oldAvatarUrl && oldAvatarUrl.startsWith("/uploads/avatars/")) {
    const oldPath = path.join(process.cwd(), oldAvatarUrl.replace(/^\//, ""));
    fs.unlink(oldPath).catch(() => {
      // Silent fail - old avatar deletion is not critical
    });
  }

  return buildUserResponse(updatedUser);
};

/**
 * Remove user avatar
 * @param {number} userId - User ID
 * @returns {Promise<Object>} Updated user
 */
export const removeUserAvatar = async (userId) => {
  const currentUser = await userRepository.findById(userId);
  const currentAvatarUrl = currentUser?.avatar_url;

  // Update user to remove avatar
  const updatedUser = await userRepository.update(userId, {
    avatarUrl: null,
  });

  // Delete avatar file (async, non-blocking)
  if (currentAvatarUrl && currentAvatarUrl.startsWith("/uploads/avatars/")) {
    const filePath = path.join(process.cwd(), currentAvatarUrl.replace(/^\//, ""));
    fs.unlink(filePath).catch(() => {
      // Silent fail
    });
  }

  return buildUserResponse(updatedUser);
};

/**
 * Build safe user response (exclude sensitive data)
 * @param {Object} user - User from database
 * @returns {Object} Safe user data
 */
function buildUserResponse(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    phone: user.phone,
    location: user.location,
    bio: user.bio,
    dietType: user.diet_type,
    activityLevel: user.activity_level,
    allergies: user.allergies,
    dailyGoal: user.daily_goal,
    notificationsEnabled: user.notifications_enabled,
    emergencyContact: user.emergency_contact,
    avatarUrl: user.avatar_url,
    authProvider: user.auth_provider,
    emailVerified: user.email_verified,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
  };
}

