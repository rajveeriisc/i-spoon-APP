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
    if (!req.file) return res.status(400).json({ message: "No file uploaded" });

    const filename = req.file.filename;
    const avatarUrl = `/uploads/avatars/${filename}`;

    // Update profile with new avatar
    const updated = await updateUserProfile(userId, { avatar_url: avatarUrl });
    
    // Delete previous avatar file asynchronously (non-blocking)
    try {
      const me = await getUserById(userId);
      const current = me?.avatar_url;
      if (current && current.startsWith('/uploads/avatars/') && current !== avatarUrl) {
        const oldPath = path.join(process.cwd(), current.replace(/^\//, ''));
        fs.promises.unlink(oldPath).catch(() => {}); // Fire and forget
      }
    } catch (_) {}

    res.json({ message: "Avatar updated", user: updated });
  } catch (err) {
    // If upload fails, clean up uploaded file
    if (req.file) {
      fs.promises.unlink(req.file.path).catch(() => {});
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


