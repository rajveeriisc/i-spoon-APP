import path from "path";
import fs from "fs";
import { getUserById, updateUserProfile } from "../models/userModel.js";
import { sanitizeUserProfile } from "../utils/sanitize.js";
import { AppError } from "../utils/errors.js";

const AVATAR_BASE = path.join(process.cwd(), "uploads", "avatars");

class UserService {
    async getMe(userId) {
        const user = await getUserById(userId);
        if (!user) throw new AppError('User not found', 404);
        return user;
    }

    async updateMe(userId, payload) {
        if (payload.email) delete payload.email; // email changes handled separately

        const sanitized = sanitizeUserProfile(payload);
        const updated = await updateUserProfile(userId, sanitized);
        return updated;
    }

    async uploadAvatar(userId, processedFile) {
        if (!processedFile) throw new AppError('No file uploaded or processing failed', 400);

        const avatarUrl = processedFile.url;
        const currentUser = await getUserById(userId);
        const oldAvatar = currentUser?.avatar_url;

        const updated = await updateUserProfile(userId, { avatar_url: avatarUrl });

        if (oldAvatar && oldAvatar !== avatarUrl) {
            this.deleteAvatarFile(oldAvatar);
        }
        return updated;
    }

    async removeAvatar(userId) {
        const currentUser = await getUserById(userId);
        const oldAvatarUrl = currentUser?.avatar_url;

        const updated = await updateUserProfile(userId, { avatar_url: null });
        this.deleteAvatarFile(oldAvatarUrl);
        return updated;
    }

    /** Safely delete an avatar file — rejects paths outside the uploads/avatars directory */
    deleteAvatarFile(avatarUrl) {
        if (!avatarUrl || !avatarUrl.startsWith("/uploads/avatars/")) return;
        const filePath = path.join(process.cwd(), avatarUrl.replace(/^\//, ""));
        if (!filePath.startsWith(AVATAR_BASE)) return; // path traversal guard
        fs.promises.unlink(filePath).catch((err) => {
            // Intentionally ignoring errors on delete if file doesn't exist etc.
        });
    }
}

export default new UserService();
