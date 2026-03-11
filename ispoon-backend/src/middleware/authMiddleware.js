import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import { SECURITY_CONFIG } from "../config/security.js";
import logger from "../utils/logger.js";
dotenv.config();

// Protect routes using JWT from Authorization header only
export const protect = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ message: "No token provided" });
  }

  const token = authHeader.split(" ")[1];
  if (!token) {
    return res.status(401).json({ message: "No token provided" });
  }

  try {
    // Verify token with issuer and audience validation
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: SECURITY_CONFIG.JWT.ISSUER,
      audience: SECURITY_CONFIG.JWT.AUDIENCE,
      algorithms: ['HS256'] // Explicitly specify allowed algorithms to prevent algorithm confusion attacks
    });

    // Validate required payload fields (never log token content)
    if (!decoded.id || !decoded.email) {
      logger.warn('Invalid token payload structure', { requestId: req.id, path: req.path });
      return res.status(401).json({ message: "Invalid token" });
    }

    req.user = decoded;
    next();
  } catch (err) {
    logger.warn('Token verification failed', {
      requestId: req.id,
      errorType: err.name,
      path: req.path,
      method: req.method,
    });

    let message = 'Authentication failed';
    if (err.name === 'TokenExpiredError') {
      message = 'Token has expired';
    } else if (err.name === 'JsonWebTokenError') {
      // Generic message — don't expose internal JWT error details to clients
      message = 'Invalid token';
    } else if (err.name === 'TokenNotBeforeError') {
      message = 'Token not active yet';
    }

    res.status(401).json({ message });
  }
};
