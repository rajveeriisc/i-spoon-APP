import { logSecurityEvent } from '../config/security.js';

// Enhanced error handler with security considerations
export const handleError = (res, error, req = null) => {
  // Log error with request details for debugging (but not in production)
  const errorDetails = {
    message: error?.message || 'Unknown error',
    stack: process.env.NODE_ENV === 'development' ? error?.stack : undefined,
    url: req?.url,
    method: req?.method,
    ip: req?.ip,
    userAgent: req?.get('User-Agent')?.substring(0, 100),
    timestamp: new Date().toISOString(),
  };

  // Log security-related errors
  if (error?.message?.includes('Invalid') || error?.message?.includes('Unauthorized')) {
    logSecurityEvent('AUTH_ERROR', errorDetails);
  }

  console.error("❌ Error:", errorDetails);

  // Don't leak sensitive information in production
  const isProduction = process.env.NODE_ENV === 'production';
  const statusCode = error?.statusCode || error?.status || 500;

  const response = {
    message: isProduction
      ? (statusCode >= 500 ? 'Internal Server Error' : 'Request Error')
      : error?.message || 'Internal Server Error',
    ...(isProduction && statusCode >= 500 && { code: 'INTERNAL_ERROR' }),
  };

  res.status(statusCode).json(response);
};

// Middleware for catching unhandled errors
export const errorMiddleware = (err, req, res, next) => {
  if (!err) return next();

  handleError(res, err, req);
};