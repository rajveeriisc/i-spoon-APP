import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import cookieParser from "cookie-parser";
import crypto from "crypto";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Routes
import apiRoutes from "./api/routes/index.js";

// Middleware
import { errorMiddleware, notFoundMiddleware } from "./api/middleware/error.middleware.js";

// Config & Utils
import { SECURITY_CONFIG, validateSecurityConfig } from "./config/security.js";
import { pool } from "./config/db.js";
import { getFirebaseAdmin } from "./config/firebaseAdmin.js";
import { logger } from "./utils/logger.js";

dotenv.config();

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Validate security configuration on startup
try {
  validateSecurityConfig();
  logger.info("Security configuration validated");
} catch (error) {
  logger.error("Security configuration error:", error);
  process.exit(1);
}

const app = express();

// Trust proxy (for Heroku, ngrok, etc.)
app.set("trust proxy", 1);

// ========== Security Middleware ==========

// Helmet for security headers
app.use(
  helmet({
    crossOriginOpenerPolicy: false,
    crossOriginEmbedderPolicy: false,
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", "data:", "https:"],
        connectSrc: [
          "'self'",
          "https://*.googleapis.com",
          "https://*.firebaseio.com",
        ],
      },
    },
  })
);

// CORS configuration
app.use(
  cors({
    origin: SECURITY_CONFIG.ALLOWED_ORIGINS,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);
app.options("*", cors());

// ========== Body Parsing ==========

app.use(cookieParser());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: false, limit: "10mb" }));

// ========== Static Files ==========

// Serve uploaded files
app.use("/uploads", (req, res, next) => {
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
  next();
});
app.use("/uploads", express.static(path.join(process.cwd(), "storage", "uploads")));

// ========== Rate Limiting ==========

const authLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.AUTH,
  message: { message: "Too many authentication attempts, please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});

const generalLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.GENERAL,
  message: { message: "Too many requests, please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});

// Apply general rate limiting to all routes
app.use(generalLimiter);

// ========== Routes ==========

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    name: "iSpoon Backend API",
    version: "2.0.0",
    status: "running",
    message: "Welcome to iSpoon Backend API ✨",
  });
});

// CSRF token generation endpoint
app.get("/api/auth/csrf", (req, res) => {
  const token = crypto.randomBytes(32).toString("hex");
  res.cookie("csrfToken", token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
  });
  res.json({ csrfToken: token });
});

// Password reset page (for email links)
app.get("/reset-password", (req, res) => {
  const token = req.query.token || "";
  // Import template dynamically
  import("./templates/reset-password-page.template.js")
    .then((module) => {
      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.send(module.getResetPasswordPage(token));
    })
    .catch(() => {
      res.status(500).send("Error loading password reset page");
    });
});

// API routes
app.use("/api", apiRoutes);

// ========== Error Handling ==========

// 404 handler
app.use(notFoundMiddleware);

// Global error middleware (must be last)
app.use(errorMiddleware);

// ========== Graceful Shutdown ==========

const gracefulShutdown = async () => {
  logger.info("Received shutdown signal, closing gracefully...");
  try {
    await pool.end();
    logger.info("Database connections closed");
    process.exit(0);
  } catch (error) {
    logger.error("Error during shutdown:", error);
    process.exit(1);
  }
};

process.on("SIGTERM", gracefulShutdown);
process.on("SIGINT", gracefulShutdown);

export default app;

