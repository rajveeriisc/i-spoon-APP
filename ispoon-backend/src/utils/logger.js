/**
 * Simple logger utility
 * In production, consider using winston or pino
 */

const isDevelopment = process.env.NODE_ENV !== "production";

export const logger = {
  info: (message, meta = {}) => {
    console.log(`[INFO] ${message}`, isDevelopment ? meta : "");
  },

  error: (message, error = {}) => {
    console.error(`[ERROR] ${message}`, isDevelopment ? error : error.message);
  },

  warn: (message, meta = {}) => {
    console.warn(`[WARN] ${message}`, isDevelopment ? meta : "");
  },

  debug: (message, meta = {}) => {
    if (isDevelopment) {
      console.debug(`[DEBUG] ${message}`, meta);
    }
  },
};

export default logger;

