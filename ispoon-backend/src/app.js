import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import cookieParser from "cookie-parser";
import dotenv from "dotenv";
import path from "path";

// Routes - all from single location
import {
  authRoutes,
  userRoutes,
  deviceRoutes,
  analyticsRoutes,
  mealsRoutes,
  emailRoutes,
  notificationRoutes,
} from "./routes/index.js";

// Config & Utils
import { errorMiddleware } from "./utils/errorHandler.js";
import { SECURITY_CONFIG, validateSecurityConfig } from "./config/security.js";
import { pool } from "./config/db.js";
import { getFirebaseAdmin } from "./config/firebaseAdmin.js";
import logger from "./utils/logger.js";
import requestId from "./middleware/requestId.js";

dotenv.config();

// Validate security configuration on startup
try {
  validateSecurityConfig();
} catch (error) {
  logger.error("Security configuration error", { error });
  process.exit(1);
}

const app = express();

// Trust first proxy (ngrok / reverse proxy in dev)
app.set('trust proxy', 1);

// ─── Security headers ─────────────────────────────────────────────────────────
app.use(helmet({
  crossOriginOpenerPolicy: false,
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://*.googleapis.com", "https://*.firebaseio.com"],
    },
  },
}));

// ─── CORS ─────────────────────────────────────────────────────────────────────
app.use(cors({
  origin: SECURITY_CONFIG.ALLOWED_ORIGINS,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
}));
app.options("*", cors());

// ─── Core middleware ──────────────────────────────────────────────────────────
app.use(requestId);        // attach req.id + X-Request-Id response header
app.use(cookieParser());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ─── Structured request logger ────────────────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
    logger[level](`${req.method} ${req.path}`, {
      requestId: req.id,
      status: res.statusCode,
      durationMs: duration,
    });
  });
  next();
});

// ─── Static file serving ──────────────────────────────────────────────────────
app.use("/uploads", (req, res, next) => {
  res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
  next();
});
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));

// ─── Rate limiters ────────────────────────────────────────────────────────────
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

// ─── Root / health ────────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.send("i-Spoon Backend API Running with NeonDB & CORS ✅");
});

app.get("/api/health", async (req, res) => {
  const health = {
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: { database: "unknown", firebase: "unknown" },
  };

  try {
    await pool.query("SELECT 1");
    health.services.database = "ok";
  } catch {
    health.services.database = "error";
    health.status = "degraded";
  }

  try {
    const admin = getFirebaseAdmin();
    health.services.firebase = admin ? "ok" : "error";
  } catch {
    health.services.firebase = "error";
    health.status = "degraded";
  }

  res.status(health.status === "ok" ? 200 : 503).json(health);
});

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use(generalLimiter);

app.use("/api/auth", authLimiter, authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/devices", deviceRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/meals", mealsRoutes);
app.use("/api/email", emailRoutes);
app.use("/api/notifications", notificationRoutes);

// ─── 404 ──────────────────────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((req, res, _next) => {
  res.status(404).json({ message: 'Not Found' });
});

// ─── Global error handler (must be last) ──────────────────────────────────────
app.use(errorMiddleware);

export default app;
