import { logSecurityEvent } from '../config/security.js';
import logger from './logger.js';

// Enhanced error handler with security considerations
export const handleError = (res, error, req = null) => {
  const isProduction = process.env.NODE_ENV === 'production';
  const statusCode = error?.statusCode || error?.status || 500;

  // Log security-related errors
  const msg = error?.message || '';
  if (msg.includes('Invalid') || msg.includes('Unauthorized')) {
    logSecurityEvent('AUTH_ERROR', {
      message: msg,
      url: req?.url,
      method: req?.method,
      ip: req?.ip,
      requestId: req?.id,
    });
  }

  if (statusCode >= 500) {
    logger.error(msg || 'Internal server error', {
      requestId: req?.id,
      url: req?.url,
      method: req?.method,
      error,
    });
  } else {
    logger.warn(msg || 'Client error', {
      requestId: req?.id,
      statusCode,
    });
  }

  const response = {
    message: isProduction
      ? (statusCode >= 500 ? 'Internal Server Error' : (msg || 'Request Error'))
      : (msg || 'Internal Server Error'),
    ...(req?.id ? { requestId: req.id } : {}),
    ...(isProduction && statusCode >= 500 ? { code: 'INTERNAL_ERROR' } : {}),
  };

  res.status(statusCode).json(response);
};

// Middleware for catching unhandled errors
export const errorMiddleware = (err, req, res, next) => {
  if (!err) return next();
  handleError(res, err, req);
};
