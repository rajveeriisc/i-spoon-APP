/**
 * Standard error codes for consistent error handling
 */
export const ErrorCodes = {
  // Authentication errors (1000-1999)
  AUTH_INVALID_CREDENTIALS: 1001,
  AUTH_TOKEN_EXPIRED: 1002,
  AUTH_TOKEN_INVALID: 1003,
  AUTH_UNAUTHORIZED: 1004,
  AUTH_EMAIL_NOT_VERIFIED: 1005,
  
  // Validation errors (2000-2999)
  VALIDATION_FAILED: 2001,
  VALIDATION_EMAIL_INVALID: 2002,
  VALIDATION_PASSWORD_WEAK: 2003,
  VALIDATION_REQUIRED_FIELD: 2004,
  VALIDATION_INVALID_FORMAT: 2005,
  
  // Resource errors (3000-3999)
  RESOURCE_NOT_FOUND: 3001,
  RESOURCE_ALREADY_EXISTS: 3002,
  RESOURCE_CONFLICT: 3003,
  
  // File errors (4000-4999)
  FILE_TOO_LARGE: 4001,
  FILE_INVALID_TYPE: 4002,
  FILE_UPLOAD_FAILED: 4003,
  
  // Server errors (5000-5999)
  SERVER_ERROR: 5001,
  DATABASE_ERROR: 5002,
  EXTERNAL_SERVICE_ERROR: 5003,
};

/**
 * Custom error class with error code
 */
export class AppError extends Error {
  constructor(message, code = ErrorCodes.SERVER_ERROR, statusCode = 500) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Format error response consistently
 */
export function formatErrorResponse(error, includeStack = false) {
  const response = {
    success: false,
    message: error.message || 'An error occurred',
    code: error.code || ErrorCodes.SERVER_ERROR,
  };
  
  if (includeStack && process.env.NODE_ENV !== 'production') {
    response.stack = error.stack;
  }
  
  return response;
}

/**
 * Create validation error
 */
export function validationError(field, message) {
  return new AppError(
    message || `Validation failed for ${field}`,
    ErrorCodes.VALIDATION_FAILED,
    400
  );
}

/**
 * Create authentication error
 */
export function authError(message = 'Authentication failed') {
  return new AppError(message, ErrorCodes.AUTH_UNAUTHORIZED, 401);
}

/**
 * Create not found error
 */
export function notFoundError(resource = 'Resource') {
  return new AppError(
    `${resource} not found`,
    ErrorCodes.RESOURCE_NOT_FOUND,
    404
  );
}







