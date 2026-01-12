/**
 * Custom Application Error class
 */
export class AppError extends Error {
  constructor(message, statusCode = 500, data = null) {
    super(message);
    this.statusCode = statusCode;
    this.data = data;
    this.isOperational = true; // Distinguish operational errors from programming errors
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Validation Error (400)
 */
export class ValidationError extends AppError {
  constructor(message, errors = []) {
    super(message, 400, { errors });
  }
}

/**
 * Authentication Error (401)
 */
export class AuthenticationError extends AppError {
  constructor(message = "Authentication required") {
    super(message, 401);
  }
}

/**
 * Authorization Error (403)
 */
export class AuthorizationError extends AppError {
  constructor(message = "Insufficient permissions") {
    super(message, 403);
  }
}

/**
 * Not Found Error (404)
 */
export class NotFoundError extends AppError {
  constructor(message = "Resource not found") {
    super(message, 404);
  }
}

/**
 * Conflict Error (409)
 */
export class ConflictError extends AppError {
  constructor(message = "Resource conflict") {
    super(message, 409);
  }
}

/**
 * Rate Limit Error (429)
 */
export class RateLimitError extends AppError {
  constructor(message = "Too many requests") {
    super(message, 429);
  }
}
