import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import { SECURITY_CONFIG } from "../config/security.js";
dotenv.config();

// Protect routes using JWT from Authorization header only
export const protect = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "No token provided" });

  try {
    // Verify token with issuer and audience validation
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: SECURITY_CONFIG.JWT.ISSUER,
      audience: SECURITY_CONFIG.JWT.AUDIENCE,
      algorithms: ['HS256'] // Explicitly specify allowed algorithms to prevent algorithm confusion attacks
    });
    
    // Additional validation
    if (!decoded.id || !decoded.email) {
      return res.status(401).json({ message: "Invalid token payload" });
    }
    
    req.user = decoded;
    next();
  } catch (err) {
    // Log error for debugging (consider using a proper logger in production)
    console.error('Token verification failed:', err.message);
    
    // Provide specific error messages for debugging in development
    const message = err.name === 'TokenExpiredError' 
      ? 'Token has expired' 
      : err.name === 'JsonWebTokenError'
      ? 'Invalid token'
      : 'Authentication failed';
    
    res.status(401).json({ message });
  }
};