/**
 * Input sanitization utilities
 * Prevents XSS, SQL injection, and other injection attacks
 */

/**
 * Sanitize HTML to prevent XSS attacks
 * Removes all HTML tags and dangerous characters
 */
export function sanitizeHtml(input) {
  if (typeof input !== 'string') return '';

  return input
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
}

/**
 * Sanitize text input - removes control characters and excessive whitespace
 */
export function sanitizeText(input, maxLength = 500) {
  if (typeof input !== 'string') return '';

  return input
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '') // Remove control characters
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim()
    .slice(0, maxLength);
}

/**
 * Sanitize email address
 */
export function sanitizeEmail(input) {
  if (typeof input !== 'string') return '';
  return input.toLowerCase().trim().slice(0, 254);
}

/**
 * Sanitize phone number - keep only digits, +, -, (, ), and spaces
 */
export function sanitizePhone(input) {
  if (typeof input !== 'string') return '';
  return input.replace(/[^0-9+\-() ]/g, '').trim().slice(0, 20);
}

/**
 * Sanitize URL
 */
export function sanitizeUrl(input) {
  if (typeof input !== 'string') return '';

  try {
    const url = new URL(input);
    // Only allow http and https protocols
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      return '';
    }
    return url.toString().slice(0, 500);
  } catch {
    return '';
  }
}

/**
 * Sanitize array of strings
 */
export function sanitizeStringArray(input, maxLength = 20, maxItemLength = 100) {
  if (!Array.isArray(input)) return [];

  return input
    .filter(item => typeof item === 'string')
    .map(item => sanitizeText(item, maxItemLength))
    .filter(item => item.length > 0)
    .slice(0, maxLength);
}

/**
 * Sanitize integer with bounds
 */
export function sanitizeInteger(input, min = 0, max = Number.MAX_SAFE_INTEGER) {
  const num = parseInt(input, 10);
  if (isNaN(num)) return null;
  return Math.max(min, Math.min(max, num));
}

/**
 * Sanitize boolean
 */
export function sanitizeBoolean(input) {
  if (typeof input === 'boolean') return input;
  if (typeof input === 'string') {
    return input.toLowerCase() === 'true';
  }
  return !!input;
}

/**
 * Sanitize nested profile_metadata object (age, gender only — unknown keys dropped)
 */
function sanitizeProfileMetadata(meta) {
  if (!meta || typeof meta !== 'object' || Array.isArray(meta)) return {};
  const safe = {};
  if (meta.age !== undefined) safe.age = sanitizeInteger(meta.age, 0, 150);
  if (meta.gender !== undefined) safe.gender = sanitizeText(meta.gender, 20);
  return safe;
}

/**
 * Sanitize bite goals object
 */
function sanitizeBiteGoals(goals) {
  if (!goals || typeof goals !== 'object' || Array.isArray(goals)) return {};
  const safe = {};
  if (goals.breakfast !== undefined) safe.breakfast = sanitizeInteger(goals.breakfast, 0, 10000);
  if (goals.lunch !== undefined) safe.lunch = sanitizeInteger(goals.lunch, 0, 10000);
  if (goals.dinner !== undefined) safe.dinner = sanitizeInteger(goals.dinner, 0, 10000);
  if (goals.snack !== undefined) safe.snack = sanitizeInteger(goals.snack, 0, 10000);
  return safe;
}

/**
 * Validate and sanitize user profile data
 */
export function sanitizeUserProfile(data) {
  const sanitized = {};

  if (data.name !== undefined) {
    sanitized.name = sanitizeText(data.name, 100);
  }

  if (data.phone !== undefined) {
    sanitized.phone = sanitizePhone(data.phone);
  }

  if (data.location !== undefined) {
    sanitized.location = sanitizeText(data.location, 200);
  }

  if (data.daily_goal !== undefined) {
    sanitized.daily_goal = sanitizeInteger(data.daily_goal, 0, 10000);
  }

  if (data.notifications_enabled !== undefined) {
    sanitized.notifications_enabled = sanitizeBoolean(data.notifications_enabled);
  }

  if (data.avatar_url !== undefined) {
    sanitized.avatar_url = sanitizeText(data.avatar_url, 500);
  }

  // Per-meal bite goals (flat fields)
  if (data.breakfast_goal !== undefined) sanitized.breakfast_goal = sanitizeInteger(data.breakfast_goal, 0, 10000);
  if (data.lunch_goal !== undefined) sanitized.lunch_goal = sanitizeInteger(data.lunch_goal, 0, 10000);
  if (data.dinner_goal !== undefined) sanitized.dinner_goal = sanitizeInteger(data.dinner_goal, 0, 10000);
  if (data.snack_goal !== undefined) sanitized.snack_goal = sanitizeInteger(data.snack_goal, 0, 10000);

  // Bite goals as nested object — sanitize each field individually
  if (data.bite_goals !== undefined) {
    sanitized.bite_goals = sanitizeBiteGoals(data.bite_goals);
  }

  // Profile metadata — only allow known fields, drop unknown keys
  if (data.age !== undefined) sanitized.age = sanitizeInteger(data.age, 0, 150);
  if (data.gender !== undefined) sanitized.gender = sanitizeText(data.gender, 20);

  if (data.profile_metadata !== undefined) {
    sanitized.profile_metadata = sanitizeProfileMetadata(data.profile_metadata);
  }

  return sanitized;
}
