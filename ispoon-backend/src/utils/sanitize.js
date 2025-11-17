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
  
  if (data.bio !== undefined) {
    sanitized.bio = sanitizeText(data.bio, 500);
  }
  
  if (data.diet_type !== undefined) {
    sanitized.diet_type = sanitizeText(data.diet_type, 50);
  }
  
  if (data.activity_level !== undefined) {
    sanitized.activity_level = sanitizeText(data.activity_level, 50);
  }
  
  if (data.allergies !== undefined) {
    sanitized.allergies = sanitizeStringArray(data.allergies, 20, 100);
  }
  
  if (data.daily_goal !== undefined) {
    sanitized.daily_goal = sanitizeInteger(data.daily_goal, 0, 10000);
  }
  
  if (data.notifications_enabled !== undefined) {
    sanitized.notifications_enabled = sanitizeBoolean(data.notifications_enabled);
  }
  
  if (data.emergency_contact !== undefined) {
    sanitized.emergency_contact = sanitizeText(data.emergency_contact, 100);
  }
  
  if (data.avatar_url !== undefined) {
    // Avatar URLs are internal paths, just sanitize as text
    sanitized.avatar_url = sanitizeText(data.avatar_url, 500);
  }
  
  return sanitized;
}







