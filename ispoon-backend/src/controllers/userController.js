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

    // Merge individual goals into bite_goals if present
    if (
      sanitized.breakfast_goal !== undefined ||
      sanitized.lunch_goal !== undefined ||
      sanitized.dinner_goal !== undefined ||
      sanitized.snack_goal !== undefined
    ) {
      // Fetch current goals to merge, or default
      const currentUser = await getUserById(userId);
      const currentGoals = currentUser.bite_goals || {
        daily: 50,
        breakfast: 15,
        lunch: 20,
        dinner: 15,
        snack: 5,
      };

      sanitized.bite_goals = {
        ...currentGoals,
        ...(sanitized.breakfast_goal !== undefined && { breakfast: sanitized.breakfast_goal }),
        ...(sanitized.lunch_goal !== undefined && { lunch: sanitized.lunch_goal }),
        ...(sanitized.dinner_goal !== undefined && { dinner: sanitized.dinner_goal }),
        ...(sanitized.snack_goal !== undefined && { snack: sanitized.snack_goal }),
      };

      // Update daily goal if needed (sum of parts or explicit)
      if (sanitized.daily_goal === undefined) {
        sanitized.bite_goals.daily =
          (sanitized.bite_goals.breakfast || 0) +
          (sanitized.bite_goals.lunch || 0) +
          (sanitized.bite_goals.dinner || 0) +
          (sanitized.bite_goals.snack || 0);
        sanitized.daily_goal = sanitized.bite_goals.daily;
      } else {
        sanitized.bite_goals.daily = sanitized.daily_goal;
      }

      // Remove flat fields so they don't confuse the model update (though model whitelists anyway)
      delete sanitized.breakfast_goal;
      delete sanitized.lunch_goal;
      delete sanitized.dinner_goal;
      delete sanitized.snack_goal;
      delete sanitized.snack_goal;
    }

    // Merge individual profile metadata fields if present
    if (
      sanitized.age !== undefined ||
      sanitized.gender !== undefined ||
      sanitized.height !== undefined ||
      sanitized.weight !== undefined
    ) {
      const currentUser = await getUserById(userId);
      const currentMeta = currentUser.profile_metadata || {};

      sanitized.profile_metadata = {
        ...currentMeta,
        ...(sanitized.age !== undefined && { age: sanitized.age }),
        ...(sanitized.gender !== undefined && { gender: sanitized.gender }),
        ...(sanitized.height !== undefined && { height: sanitized.height }),
        ...(sanitized.weight !== undefined && { weight: sanitized.weight }),
      };

      // Cleanup flat fields
      delete sanitized.age;
      delete sanitized.gender;
      delete sanitized.height;
      delete sanitized.weight;
    }

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
      fs.promises.unlink(oldPath).catch(() => { }); // Fire and forget
    }

    res.json({
      message: "Avatar updated and optimized",
      user: updated
    });
  } catch (err) {
    // If upload fails, clean up processed file
    if (req.processedFile?.path) {
      fs.promises.unlink(req.processedFile.path).catch(() => { });
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
        fs.promises.unlink(filePath).catch(() => { }); // Fire and forget
      }
    } catch (_) { }

    res.json({ message: "Avatar removed", user: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


