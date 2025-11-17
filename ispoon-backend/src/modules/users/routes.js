import express from "express";
import { getMe, updateMe, uploadAvatar, removeAvatar } from "../../controllers/userController.js";
import { protect } from "../../middleware/authMiddleware.js";
import { validateUpdateMe } from "../../middleware/validation.js";
import multer from "multer";
import sharp from "sharp";
import path from "path";
import fs from "fs";

const router = express.Router();

// Use memory storage for image processing with sharp
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { 
    fileSize: 5 * 1024 * 1024, // 5MB max upload (will be compressed to ~100KB)
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowedMimeTypes.includes(file.mimetype)) {
      return cb(new Error('Only PNG, JPG, JPEG, and WebP images allowed'), false);
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
    
    const filename = `u_${Date.now()}_${Math.random().toString(36).slice(2,8)}.webp`;
    const filepath = path.join(uploadsDir, filename);
    
    // Optimize image: resize to 400x400 and compress
    await sharp(req.file.buffer)
      .resize(400, 400, {
        fit: 'cover',
        position: 'center'
      })
      .webp({ quality: 85 })  // Convert to WebP, 85% quality
      .toFile(filepath);
    
    // Attach processed file info to request
    req.processedFile = {
      filename,
      path: filepath,
      url: `/uploads/avatars/${filename}`
    };
    
    next();
  } catch (error) {
    next(new Error('Image processing failed: ' + error.message));
  }
};

router.get('/me', protect, getMe);
router.put('/me', protect, validateUpdateMe, updateMe);
router.post('/me/avatar', protect, upload.single('avatar'), optimizeImage, uploadAvatar);
router.delete('/me/avatar', protect, removeAvatar);

export default router;


