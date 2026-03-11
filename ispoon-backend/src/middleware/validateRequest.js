import { z } from 'zod';
import { AppError } from '../utils/errors.js';

/**
 * Middleware to validate incoming request body, query, or params
 * against a provided Zod schema.
 * 
 * @param {z.ZodSchema} schema 
 * @param {'body' | 'query' | 'params'} property 
 */
/**
 * Middleware to validate incoming request against a provided Zod schema.
 *
 * Schemas define any combination of `body`, `params`, and `query` keys.
 * The middleware passes { body, params, query } to the schema so all three
 * can be validated together. After a successful parse the validated values
 * are written back to req so downstream handlers always see sanitised data.
 *
 * @param {z.ZodSchema} schema
 */
export const validateRequest = (schema) => {
    return (req, res, next) => {
        try {
            const parsed = schema.parse({
                body: req.body,
                params: req.params,
                query: req.query,
            });
            if (parsed.body   !== undefined) req.body   = parsed.body;
            if (parsed.params !== undefined) req.params = parsed.params;
            if (parsed.query  !== undefined) req.query  = parsed.query;
            next();
        } catch (error) {
            if (error instanceof z.ZodError) {
                const errorMessages = error.errors
                    .map(err => `${err.path.join('.')}: ${err.message}`)
                    .join(', ');
                next(new AppError(`Validation Failed: ${errorMessages}`, 400));
            } else {
                next(error);
            }
        }
    };
};
