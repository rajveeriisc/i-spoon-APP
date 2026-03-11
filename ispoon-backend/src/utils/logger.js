/**
 * Structured logger utility
 * Outputs JSON-style logs in production, pretty-printed with colours in development.
 * Each log line includes: level, timestamp, requestId (when available), message, and
 * any extra metadata passed as the second argument.
 *
 * Usage:
 *   import logger from '../utils/logger.js';
 *   logger.info('User created', { userId: 42 });
 *   logger.error('DB failed', error);
 *
 * Request-scoped logging (attach requestId from middleware):
 *   const log = logger.child({ requestId: req.id });
 *   log.info('Processing request');
 */

const isDev = process.env.NODE_ENV !== 'production';

// ANSI colour codes — only applied in dev
const COLOURS = {
  reset:  '\x1b[0m',
  grey:   '\x1b[90m',
  cyan:   '\x1b[36m',
  green:  '\x1b[32m',
  yellow: '\x1b[33m',
  red:    '\x1b[31m',
  blue:   '\x1b[34m',
};

const LEVEL_COLOUR = {
  DEBUG: COLOURS.grey,
  INFO:  COLOURS.green,
  WARN:  COLOURS.yellow,
  ERROR: COLOURS.red,
};

// ─── Core emit ────────────────────────────────────────────────────────────────

/**
 * @param {'DEBUG'|'INFO'|'WARN'|'ERROR'} level
 * @param {string}  message
 * @param {object}  meta   - arbitrary key/value pairs to include in the log
 * @param {object}  ctx    - inherited context from a child logger (e.g. requestId)
 */
const emit = (level, message, meta = {}, ctx = {}) => {
  const timestamp = new Date().toISOString();

  // Flatten context + meta; context values come first (lower precedence)
  const payload = { ...ctx, ...flattenMeta(meta) };

  if (isDev) {
    // Pretty-printed for terminal readability
    const colour  = LEVEL_COLOUR[level] || COLOURS.reset;
    const label   = `${colour}[${level}]${COLOURS.reset}`;
    const ts      = `${COLOURS.grey}${timestamp}${COLOURS.reset}`;
    const rid     = payload.requestId
      ? ` ${COLOURS.cyan}[${payload.requestId}]${COLOURS.reset}`
      : '';

    const { requestId: _r, ...rest } = payload;
    const extra = Object.keys(rest).length ? ` ${JSON.stringify(rest)}` : '';

    const out = `${ts} ${label}${rid} ${message}${extra}`;

    if (level === 'ERROR') {
      console.error(out);
    } else if (level === 'WARN') {
      console.warn(out);
    } else {
      console.log(out);
    }
  } else {
    // Structured JSON — easy to parse with Datadog / CloudWatch / etc.
    const entry = {
      level,
      timestamp,
      message,
      ...payload,
    };

    if (level === 'ERROR') {
      console.error(JSON.stringify(entry));
    } else {
      console.log(JSON.stringify(entry));
    }
  }
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Converts Error objects into a plain serialisable shape; passes everything
 * else through unchanged.
 */
const flattenMeta = (meta) => {
  if (!meta || typeof meta !== 'object') return {};
  if (meta instanceof Error) {
    return {
      errorMessage: meta.message,
      errorName:    meta.name,
      ...(isDev && meta.stack ? { stack: meta.stack } : {}),
    };
  }
  // Shallow-clone so we never mutate caller's object
  const out = { ...meta };
  if (out instanceof Error) return flattenMeta(out); // edge case
  // Recursively handle an `error` key that contains an Error instance
  if (out.error instanceof Error) {
    const { error, ...rest } = out;
    return {
      ...rest,
      errorMessage: error.message,
      errorName:    error.name,
      ...(isDev && error.stack ? { stack: error.stack } : {}),
    };
  }
  return out;
};

// ─── Public logger ────────────────────────────────────────────────────────────

const logger = {
  debug: (message, meta = {}) => emit('DEBUG', message, meta),
  info:  (message, meta = {}) => emit('INFO',  message, meta),
  warn:  (message, meta = {}) => emit('WARN',  message, meta),
  error: (message, meta = {}) => emit('ERROR', message, meta),

  /**
   * Returns a child logger that automatically includes `context` in every log.
   * Ideal for per-request logging so every line carries the requestId.
   *
   * @param {object} context - e.g. { requestId: '...', userId: '...' }
   * @returns {object} child logger with the same info/warn/error/debug API
   */
  child: (context = {}) => ({
    debug: (message, meta = {}) => emit('DEBUG', message, meta, context),
    info:  (message, meta = {}) => emit('INFO',  message, meta, context),
    warn:  (message, meta = {}) => emit('WARN',  message, meta, context),
    error: (message, meta = {}) => emit('ERROR', message, meta, context),
  }),
};

export default logger;
