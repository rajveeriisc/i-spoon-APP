import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import cookieParser from "cookie-parser";
import crypto from "crypto";
import dotenv from "dotenv";
import path from "path";

// Routes - all from single location
import {
  authRoutes,
  userRoutes,
  deviceRoutes,
  analyticsRoutes,
  mockRoutes,
  mealsRoutes,
  emailRoutes,
  notificationRoutes,
} from "./routes/index.js";

// Config & Utils
import { errorMiddleware } from "./utils/errorHandler.js";
import { SECURITY_CONFIG, validateSecurityConfig } from "./config/security.js";
import { pool } from "./config/db.js";
import { getFirebaseAdmin } from "./config/firebaseAdmin.js";

dotenv.config();

// Validate security configuration
try {
  validateSecurityConfig();
} catch (error) {
  console.error("❌ Security configuration error:", error.message);
  process.exit(1);
}

const app = express();
// after: const app = express();
app.set('trust proxy', 1); // trust first proxy (ngrok)
// Security headers with COOP/COEP disabled for dev (GIS popups)
app.use(helmet({
  crossOriginOpenerPolicy: false,
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://*.googleapis.com", "https://*.firebaseio.com"],
    },
  },
}));

// CORS configuration - restrict origins for production
app.use(cors({
  origin: SECURITY_CONFIG.ALLOWED_ORIGINS,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.options("*", cors());

app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true })); // Support nested objects in form data


// Serve static uploads
app.use("/uploads", (req, res, next) => {
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
  next();
});
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));

// Stricter rate limits for security using config
const authLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.AUTH,
  message: { message: 'Too many authentication attempts, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const generalLimiter = rateLimit({
  ...SECURITY_CONFIG.RATE_LIMITS.GENERAL,
  message: { message: 'Too many requests, please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Default route
app.get("/", (req, res) => {
  res.send(" i-Spoon Backend API Running with NeonDB & CORS ✅");
});

// CSRF token generation endpoint
app.get("/api/auth/csrf", (req, res) => {
  const token = crypto.randomBytes(32).toString('hex');
  res.cookie('csrfToken', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  });
  res.json({ csrfToken: token });
});

// Health check endpoint
app.get("/api/health", async (req, res) => {
  const health = {
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {
      database: "unknown",
      firebase: "unknown"
    }
  };

  // Check database connection
  try {
    await pool.query("SELECT 1");
    health.services.database = "ok";
  } catch (err) {
    health.services.database = "error";
    health.status = "degraded";
  }

  // Check Firebase Admin initialization
  try {
    const admin = getFirebaseAdmin();
    if (admin) {
      health.services.firebase = "ok";
    }
  } catch (err) {
    health.services.firebase = "error";
    health.status = "degraded";
  }

  res.status(health.status === "ok" ? 200 : 503).json(health);
});

// Apply general rate limiting to all routes
app.use(generalLimiter);

// Auth routes with stricter limits
app.use("/api/auth", authLimiter, authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/devices", deviceRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/meals", mealsRoutes);
app.use("/api/email", emailRoutes); // Welcome email endpoint
app.use("/api/notifications", notificationRoutes); // Notification system

// Mock data generation (development/testing only)
if (process.env.NODE_ENV !== 'production') {
  app.use("/api/mock", mockRoutes);
  console.log("🎲 Mock data endpoints enabled (development mode)");
}

// Note: Password reset is handled by Firebase (no custom page needed)

// 404 handler
// eslint-disable-next-line no-unused-vars
app.use((req, res, _next) => {
  res.status(404).json({ message: 'Not Found' });
});

// Global error middleware (must be last)
app.use(errorMiddleware);

// Export app AFTER all middleware is registered
export default app;

