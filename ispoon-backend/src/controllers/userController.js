import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import { getUserById, updateUserProfile } from "../models/userModel.js";
import { sanitizeUserProfile } from "../utils/sanitize.js";

export const getMe = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });
    const user = await getUserById(userId);
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json({ user });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

export const updateMe = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const payload = req.body || {};
    if (payload.email) delete payload.email; // email changes handled separately if needed

    // Sanitize all input fields
    const sanitized = sanitizeUserProfile(payload);

    const updated = await updateUserProfile(userId, sanitized);
    res.json({ message: "Profile updated", user: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

export const uploadAvatar = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });
    
    // Check for optimized file from sharp middleware
    if (!req.processedFile) {
      return res.status(400).json({ message: "No file uploaded or processing failed" });
    }

    const avatarUrl = req.processedFile.url;

    // Get current user to delete old avatar
    const currentUser = await getUserById(userId);
    const oldAvatar = currentUser?.avatar_url;
    
    // Update profile with new avatar
    const updated = await updateUserProfile(userId, { avatar_url: avatarUrl });
    
    // Delete previous avatar file (if exists and different)
    if (oldAvatar && oldAvatar.startsWith('/uploads/avatars/') && oldAvatar !== avatarUrl) {
      const oldPath = path.join(process.cwd(), oldAvatar.replace(/^\//, ''));
      fs.promises.unlink(oldPath).catch(() => {}); // Fire and forget
    }

    res.json({ 
      message: "Avatar updated and optimized", 
      user: updated 
    });
  } catch (err) {
    // If upload fails, clean up processed file
    if (req.processedFile?.path) {
      fs.promises.unlink(req.processedFile.path).catch(() => {});
    }
    res.status(500).json({ message: err.message });
  }
};

export const removeAvatar = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });
    
    // Update profile first
    const updated = await updateUserProfile(userId, { avatar_url: null });
    
    // Delete file asynchronously (non-blocking)
    try {
      const me = await getUserById(userId);
      const current = me?.avatar_url;
      if (current && current.startsWith('/uploads/avatars/')) {
        const filePath = path.join(process.cwd(), current.replace(/^\//, ''));
        fs.promises.unlink(filePath).catch(() => {}); // Fire and forget
      }
    } catch (_) {}
    
    res.json({ message: "Avatar removed", user: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


