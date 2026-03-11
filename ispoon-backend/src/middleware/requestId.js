/**
 * requestId middleware
 *
 * Attaches a unique request ID to every incoming request so logs can be
 * correlated across the entire request lifecycle.
 *
 * ID priority (highest → lowest):
 *  1. X-Request-Id header sent by the client / API gateway
 *  2. X-Correlation-Id header
 *  3. Newly generated short UUID (8 hex chars, fast and readable)
 *
 * The resolved ID is stored on:
 *  - req.id         — for controllers / services
 *  - res header     — X-Request-Id so clients can trace calls
 */

import { randomBytes } from 'crypto';

/** Generate a short, URL-safe request ID (e.g. "a3f9b1c2") */
const generateId = () => randomBytes(4).toString('hex');

const requestId = (req, res, next) => {
  const id =
    req.headers['x-request-id'] ||
    req.headers['x-correlation-id'] ||
    generateId();

  req.id = id;
  res.setHeader('X-Request-Id', id);
  next();
};

export default requestId;
