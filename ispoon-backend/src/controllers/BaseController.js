import logger from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * BaseController provides a standardized structure for handling 
 * requests, responses, and errors across the backend in compliance 
 * with the backend-dev-guidelines.
 */
export default class BaseController {

    /**
     * Handles successful responses
     * @param {Object} res - Express response object
     * @param {Object} data - The data payload to send
     * @param {String} message - An optional success message
     * @param {Number} statusCode - HTTP status code (defaults to 200)
     */
    handleSuccess(res, data = {}, message = 'Success', statusCode = 200) {
        res.status(statusCode).json({
            status: 'success',
            message,
            data
        });
    }

    /**
     * Centralized error handler for controllers.
     * Logs the error (ready for future Sentry hookup) and passes it to the next middleware.
     * @param {Error} error - The caught error
     * @param {Object} req - Express request object
     * @param {Function} next - Express next middleware function
     * @param {String} operationContext - Name of the method/operation where error occurred
     */
    handleError(error, req, next, operationContext = 'UnknownOperation') {
        logger.error(`[${operationContext}] Error: ${error.message}`, {
            stack: error.stack,
            path: req.originalUrl,
            method: req.method
        });

        // Future integration point for Sentry
        // Sentry.captureException(error);

        // Pass to global error handler
        next(error);
    }
}
