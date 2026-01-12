import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import { SECURITY_CONFIG } from "../config/security.js";
dotenv.config();

// Protect routes using JWT from Authorization header only
export const protect = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    console.error('❌ No Authorization header found');
    return res.status(401).json({ message: "No token provided" });
  }

  const token = authHeader.split(" ")[1];
  if (!token) {
    console.error('❌ No token found in Authorization header');
    return res.status(401).json({ message: "No token provided" });
  }



  try {
    // Verify token with issuer and audience validation
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      issuer: SECURITY_CONFIG.JWT.ISSUER,
      audience: SECURITY_CONFIG.JWT.AUDIENCE,
      algorithms: ['HS256'] // Explicitly specify allowed algorithms to prevent algorithm confusion attacks
    });
    // Additional validation
    if (!decoded.id || !decoded.email) {
      console.error('❌ Invalid token payload:', { id: decoded.id, email: decoded.email });
      return res.status(401).json({ message: "Invalid token payload" });
    }
    
    req.user = decoded;
    next();
  } catch (err) {
    // Log detailed error for debugging
    console.error('❌ Token verification failed:', {
      error: err.message,
      name: err.name,
      path: req.path,
      method: req.method,
      expectedIssuer: SECURITY_CONFIG.JWT.ISSUER,
      expectedAudience: SECURITY_CONFIG.JWT.AUDIENCE,
    });
    
    // Provide specific error messages for debugging
    let message = 'Authentication failed';
    if (err.name === 'TokenExpiredError') {
      message = 'Token has expired';
    } else if (err.name === 'JsonWebTokenError') {
      message = `Invalid token: ${err.message}`;
    } else if (err.name === 'TokenNotBeforeError') {
      message = 'Token not active yet';
    }
    
    res.status(401).json({ message, error: process.env.NODE_ENV === 'development' ? err.message : undefined });
  }
};