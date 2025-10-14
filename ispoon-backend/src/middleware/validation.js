import {
  sanitizeString,
  sanitizeNumber,
  sanitizeBoolean,
  sanitizeArray,
  isValidEmail
} from '../utils/validators.js';

export const validateUpdateMe = (req, res, next) => {
  const b = req.body || {};
  const errors = {};

  // Validate and sanitize each field
  if (b.name !== undefined) {
    if (typeof b.name !== 'string') {
      errors.name = 'name must be a string';
    } else {
      b.name = sanitizeString(b.name, 100);
    }
  }

  if (b.phone !== undefined) {
    if (typeof b.phone !== 'string') {
      errors.phone = 'phone must be a string';
    } else {
      b.phone = sanitizeString(b.phone, 20);
    }
  }

  if (b.location !== undefined) {
    if (typeof b.location !== 'string') {
      errors.location = 'location must be a string';
    } else {
      b.location = sanitizeString(b.location, 200);
    }
  }

  if (b.bio !== undefined) {
    if (typeof b.bio !== 'string') {
      errors.bio = 'bio must be a string';
    } else {
      b.bio = sanitizeString(b.bio, 500);
    }
  }

  if (b.diet_type !== undefined) {
    if (typeof b.diet_type !== 'string') {
      errors.diet_type = 'diet_type must be a string';
    } else {
      b.diet_type = sanitizeString(b.diet_type, 50);
    }
  }

  if (b.activity_level !== undefined) {
    if (typeof b.activity_level !== 'string') {
      errors.activity_level = 'activity_level must be a string';
    } else {
      b.activity_level = sanitizeString(b.activity_level, 50);
    }
  }

  if (b.allergies !== undefined) {
    if (!Array.isArray(b.allergies)) {
      errors.allergies = 'allergies must be an array';
    } else {
      b.allergies = sanitizeArray(b.allergies, 20);
    }
  }

  if (b.daily_goal !== undefined) {
    if (typeof b.daily_goal !== 'number' || isNaN(b.daily_goal)) {
      errors.daily_goal = 'daily_goal must be a number';
    } else {
      b.daily_goal = sanitizeNumber(b.daily_goal, 0, 10000);
    }
  }

  if (b.notifications_enabled !== undefined) {
    if (typeof b.notifications_enabled !== 'boolean' &&
        typeof b.notifications_enabled !== 'string') {
      errors.notifications_enabled = 'notifications_enabled must be a boolean';
    } else {
      b.notifications_enabled = sanitizeBoolean(b.notifications_enabled);
    }
  }

  if (b.emergency_contact !== undefined) {
    if (typeof b.emergency_contact !== 'string') {
      errors.emergency_contact = 'emergency_contact must be a string';
    } else {
      b.emergency_contact = sanitizeString(b.emergency_contact, 100);
    }
  }

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({
      message: 'Validation failed',
      errors
    });
  }

  // Replace request body with sanitized data
  req.body = b;
  next();
};


