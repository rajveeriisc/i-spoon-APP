import express from "express";
import { getMe, updateMe, uploadAvatar, removeAvatar } from "../../controllers/userController.js";
import { protect } from "../../middleware/authMiddleware.js";
import { validateUpdateMe } from "../../middleware/validation.js";
import multer from "multer";
import path from "path";
import fs from "fs";

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(process.cwd(), "uploads", "avatars");
    fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const safeExt = [".png", ".jpg", ".jpeg", ".webp"].includes(ext) ? ext : ".jpg";
    const name = `u_${Date.now()}_${Math.random().toString(36).slice(2,8)}${safeExt}`;
    cb(null, name);
  },
});
const upload = multer({
  storage,
  limits: { 
    fileSize: 2 * 1024 * 1024, // 2MB max file size
    files: 1 // Only 1 file allowed
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExt = [".png", ".jpg", ".jpeg", ".webp"];
    const allowedMimeTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    
    // Validate file extension
    if (!allowedExt.includes(ext)) {
      return cb(new Error('Invalid file extension. Only PNG, JPG, JPEG, and WebP are allowed.'), false);
    }
    
    // Validate MIME type
    if (!allowedMimeTypes.includes(file.mimetype)) {
      return cb(new Error('Invalid file type. Only image files are allowed.'), false);
    }
    
    cb(null, true);
  },
});

router.get('/me', protect, getMe);
router.put('/me', protect, validateUpdateMe, updateMe);
router.post('/me/avatar', protect, upload.single('avatar'), uploadAvatar);
router.delete('/me/avatar', protect, removeAvatar);

export default router;


