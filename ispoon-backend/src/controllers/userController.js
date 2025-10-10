import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import { getUserById, updateUserProfile } from "../models/userModel.js";
import { sanitizeEmail } from "../utils/validators.js";

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

    // Normalize/select allowed fields, include ONLY keys present in payload
    const fields = {};
    const copyIfPresent = (key, transform = (v) => v) => {
      if (Object.prototype.hasOwnProperty.call(payload, key)) {
        fields[key] = transform(payload[key]);
      }
    };
    copyIfPresent('name', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('phone', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('location', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('bio', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('diet_type', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('activity_level', (v) => (typeof v === 'string' ? v : undefined));
    copyIfPresent('allergies', (v) => (Array.isArray(v) ? v : undefined));
    copyIfPresent('daily_goal', (v) => (typeof v === 'number' ? Math.round(v) : undefined));
    copyIfPresent('notifications_enabled', (v) => (typeof v === 'boolean' ? v : undefined));
    copyIfPresent('emergency_contact', (v) => (typeof v === 'string' ? v : undefined));

    const updated = await updateUserProfile(userId, fields);
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

    // Delete previous avatar file if exists
    try {
      const me = await getUserById(userId);
      const current = me?.avatar_url;
      if (current && current.startsWith('/uploads/avatars/')) {
        const oldPath = path.join(process.cwd(), current.replace(/^\//, ''));
        try { fs.unlinkSync(oldPath); } catch (_) {}
      }
    } catch (_) {}

    const filename = req.file.filename;
    const avatarUrl = `/uploads/avatars/${filename}`;

    const updated = await updateUserProfile(userId, { avatar_url: avatarUrl });
    res.json({ message: "Avatar updated", user: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

export const removeAvatar = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });
    const me = await getUserById(userId);
    const current = me?.avatar_url;
    if (current && current.startsWith('/uploads/avatars/')) {
      // Resolve against process cwd to the same /uploads path served in app.js
      // Strip leading slash to avoid path.join swallowing previous segments
      const filePath = path.join(process.cwd(), current.replace(/^\//, ''));
      try { fs.unlinkSync(filePath); } catch (_) {}
    }
    const updated = await updateUserProfile(userId, { avatar_url: null });
    res.json({ message: "Avatar removed", user: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


