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
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const allowedExt = [".png", ".jpg", ".jpeg", ".webp", ".heic", ".heif"];
    const typeOk = /image\/(png|jpe?g|webp|heic|heif)/i.test(String(file.mimetype || ""));
    const ok = typeOk || allowedExt.includes(ext);
    cb(ok ? null : new Error("Invalid file type"), ok);
  },
});

router.get('/me', protect, getMe);
router.put('/me', protect, validateUpdateMe, updateMe);
router.post('/me/avatar', protect, upload.single('avatar'), uploadAvatar);
router.delete('/me/avatar', protect, removeAvatar);

export default router;


