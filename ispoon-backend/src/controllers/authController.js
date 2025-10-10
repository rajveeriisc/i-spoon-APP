import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import dotenv from "dotenv";
import { createUser, getUserByEmail, setResetTokenForUser, getUserByResetToken, clearResetTokenAndSetPassword } from "../models/userModel.js";
import { sendWelcomeEmail, sendPasswordResetEmail, buildResetPasswordUrl } from "../emails/service.js";
import {
  sanitizeEmail,
  validateSignup,
  validateLogin,
} from "../utils/validators.js";

dotenv.config();

// 🔹 Signup Controller
export const signup = async (req, res) => {
  try {
    const { email, password, name } = req.body || {};
    const { valid, errors } = validateSignup({ email, password });
    if (!valid) return res.status(400).json({ message: "Validation failed", errors });

    const normalizedEmail = sanitizeEmail(email);
    const existing = await getUserByEmail(normalizedEmail);
    if (existing)
      return res.status(400).json({ message: "User already exists" });

    const hashed = await bcrypt.hash(password, 10);
    const newUser = await createUser(normalizedEmail, hashed, name);

    // Fire-and-forget welcome email (do not block response)
    Promise.resolve().then(() => {
      sendWelcomeEmail({ to: newUser.email, name: newUser.name }).catch((e) => {
        console.error("Welcome email failed:", e?.message || e);
      });
    });

    res.status(201).json({ message: "Signup successful", user: newUser });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🔹 Login Controller
export const login = async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const { valid, errors } = validateLogin({ email, password });
    if (!valid) return res.status(400).json({ message: "Validation failed", errors });

    const normalizedEmail = sanitizeEmail(email);
    const user = await getUserByEmail(normalizedEmail);
    if (!user) return res.status(400).json({ message: "Invalid credentials" });

    const match = await bcrypt.compare(password, user.password);
    if (!match) return res.status(400).json({ message: "Invalid credentials" });

    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      message: "Login successful",
      token,
      user: { id: user.id, email: user.email, name: user.name },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🔹 Logout Controller - noop for bearer token flow
export const logout = async (_req, res) => {
  res.json({ message: 'Logged out' });
};

// 🔹 Forgot Password: send reset link
export const forgotPassword = async (req, res) => {
  try {
    const email = (req.body?.email || "").trim().toLowerCase();
    if (!email) return res.status(400).json({ message: "Email is required" });
    const user = await getUserByEmail(email);
    if (!user) return res.status(404).json({ message: "Account not found" });

    // Generate secure token and expiry (1 hour)
    const token = crypto.randomBytes(32).toString("hex");
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    await setResetTokenForUser(email, token, expiresAt);

    const resetUrl = buildResetPasswordUrl(token);
    try {
      await sendPasswordResetEmail({ to: email, resetUrl });
    } catch (e) {
      console.error("Email send failed:", e?.message || e);
    }

    res.json({ message: "Reset link sent" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// 🔹 Reset Password: verify token and set new password
export const resetPassword = async (req, res) => {
  try {
    const token = (req.body?.token || req.body?.Token || req.body?.TOKEN || "").toString().trim();
    const newPassword = (req.body?.password || req.body?.Password || "").toString();
    if (!token || !newPassword) return res.status(400).json({ message: "Token and password are required" });
    if (typeof newPassword !== 'string' || newPassword.length < 8 ||
        !/[A-Z]/.test(newPassword) || !/[a-z]/.test(newPassword) ||
        !/[0-9]/.test(newPassword) || !/[^A-Za-z0-9]/.test(newPassword)) {
      return res.status(400).json({ message: "Password must be 8+ chars with upper, lower, number, special" });
    }
    const user = await getUserByResetToken(token);
    if (!user) {
      const wantsHtml = String(req.headers?.accept || "").includes("text/html") ||
        String(req.headers["content-type"] || "").includes("application/x-www-form-urlencoded");
      if (wantsHtml) {
        const html = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Reset Password • Error</title>
<style>
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:linear-gradient(135deg,#0f172a,#111827);color:#e5e7eb;display:grid;place-items:center;height:100svh}
  .box{background:rgba(17,24,39,.9);padding:28px 24px;border-radius:14px;border:1px solid rgba(255,255,255,.08);max-width:520px;width:calc(100% - 32px);text-align:center}
  h2{margin:6px 0 10px}
  p{margin:0 0 14px;color:#cbd5e1}
  .btn{display:inline-block;padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.16);color:#e5e7eb;text-decoration:none}
</style></head>
<body><div class="box">
  <h2>Link is invalid or expired</h2>
  <p>Please request a new password reset link and try again.</p>
  <a class="btn" href="/reset-password">Back</a>
</div></body></html>`;
        res.setHeader("Content-Type", "text/html; charset=utf-8");
        return res.status(400).send(html);
      }
      return res.status(400).json({ message: "Invalid or expired token" });
    }
    const hashed = await bcrypt.hash(newPassword, 10);
    await clearResetTokenAndSetPassword(user.id, hashed);

    const wantsHtml = String(req.headers?.accept || "").includes("text/html") ||
      String(req.headers["content-type"] || "").includes("application/x-www-form-urlencoded");
    if (wantsHtml) {
      const html = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Password Updated • SmartSpoon</title>
<style>
  :root{--ok:#10b981}
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:linear-gradient(135deg,#0f172a,#111827);color:#e5e7eb;display:grid;place-items:center;height:100svh}
  .box{background:rgba(17,24,39,.9);padding:32px 28px;border-radius:16px;border:1px solid rgba(255,255,255,.08);max-width:560px;width:calc(100% - 32px);text-align:center}
  .check{width:96px;height:96px;margin:0 auto 10px}
  .check circle{fill:none;stroke:var(--ok);stroke-width:8;stroke-linecap:round;stroke-dasharray:314;stroke-dashoffset:314;animation:draw 900ms ease forwards}
  .check path{fill:none;stroke:var(--ok);stroke-width:8;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:100;stroke-dashoffset:100;animation:draw 600ms 500ms ease forwards}
  @keyframes draw{to{stroke-dashoffset:0}}
  h2{margin:8px 0 6px}
  p{margin:0 0 14px;color:#cbd5e1}
  .btn{display:inline-block;padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.16);color:#e5e7eb;text-decoration:none}
</style></head>
<body><div class="box">
  <svg class="check" viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
    <circle cx="60" cy="60" r="50"/>
    <path d="M36 62 L54 78 L86 42"/>
  </svg>
  <h2>Password updated!</h2>
  <p>You can now close this page and log in.</p>
  <a class="btn" href="/">Return to SmartSpoon</a>
</div></body></html>`;
      res.setHeader("Content-Type", "text/html; charset=utf-8");
      return res.send(html);
    }

    res.json({ message: "Password updated" });
  } catch (err) {
    const wantsHtml = String(req.headers?.accept || "").includes("text/html") ||
      String(req.headers["content-type"] || "").includes("application/x-www-form-urlencoded");
    if (wantsHtml) {
      const html = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Reset Password • Error</title>
<style>
  body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:linear-gradient(135deg,#0f172a,#111827);color:#e5e7eb;display:grid;place-items:center;height:100svh}
  .box{background:rgba(17,24,39,.9);padding:28px 24px;border-radius:14px;border:1px solid rgba(255,255,255,.08);max-width:520px;width:calc(100% - 32px);text-align:center}
  h2{margin:6px 0 10px}
  p{margin:0 0 14px;color:#cbd5e1}
  .btn{display:inline-block;padding:10px 14px;border-radius:10px;border:1px solid rgba(255,255,255,.16);color:#e5e7eb;text-decoration:none}
</style></head>
<body><div class="box">
  <h2>Something went wrong</h2>
  <p>${(err?.message || 'Please try again').replace(/</g,'&lt;')}</p>
  <a class="btn" href="/reset-password">Back</a>
</div></body></html>`;
      res.setHeader("Content-Type", "text/html; charset=utf-8");
      return res.status(500).send(html);
    }
    res.status(500).json({ message: err.message });
  }
};