import express from "express";
import multer from "multer";
import sharp from "sharp";
import path from "path";
import fs from "fs";
import { getMe, updateMe, uploadAvatar, removeAvatar } from "../controllers/userController.js";
import { protect } from "../middleware/authMiddleware.js";
import { validateUpdateMe } from "../middleware/validation.js";

const router = express.Router();

// Image upload configuration
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB max
        files: 1,
    },
    fileFilter: (req, file, cb) => {
        const allowedMimeTypes = ["image/png", "image/jpeg", "image/jpg", "image/webp"];
        if (!allowedMimeTypes.includes(file.mimetype)) {
            return cb(new Error("Only PNG, JPG, JPEG, and WebP images allowed"), false);
        }
        cb(null, true);
    },
});

// Image optimization middleware
const optimizeImage = async (req, res, next) => {
    if (!req.file) return next();

    try {
        const uploadsDir = path.join(process.cwd(), "uploads", "avatars");
        fs.mkdirSync(uploadsDir, { recursive: true });

        const filename = `u_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.webp`;
        const filepath = path.join(uploadsDir, filename);

        await sharp(req.file.buffer)
            .resize(400, 400, { fit: "cover", position: "center" })
            .webp({ quality: 85 })
            .toFile(filepath);

        req.processedFile = {
            filename,
            path: filepath,
            url: `/uploads/avatars/${filename}`,
        };

        next();
    } catch (error) {
        next(new Error("Image processing failed: " + error.message));
    }
};

// All routes require authentication
router.get("/me", protect, getMe);
router.put("/me", protect, validateUpdateMe, updateMe);
router.post("/me/avatar", protect, upload.single("avatar"), optimizeImage, uploadAvatar);
router.delete("/me/avatar", protect, removeAvatar);

export default router;
