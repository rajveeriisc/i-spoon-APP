import {
  sanitizeString,
  sanitizeNumber,
  sanitizeBoolean,
} from '../utils/validators.js';

// ─── User profile ─────────────────────────────────────────────────────────────

export const validateUpdateMe = (req, res, next) => {
  const b = req.body || {};
  const errors = {};

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

  if (b.gender !== undefined) {
    if (typeof b.gender !== 'string') {
      errors.gender = 'gender must be a string';
    } else {
      b.gender = sanitizeString(b.gender, 20);
    }
  }

  if (b.age !== undefined) {
    const age = Number(b.age);
    if (!Number.isInteger(age) || age < 1 || age > 150) {
      errors.age = 'age must be an integer between 1 and 150';
    } else {
      b.age = age;
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

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }

  req.body = b;
  next();
};

// ─── Meals ────────────────────────────────────────────────────────────────────

const MEAL_TYPES = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

export const validateCreateMeal = (req, res, next) => {
  const b = req.body || {};
  const errors = {};

  if (!b.meal_type) {
    errors.meal_type = 'meal_type is required';
  } else if (!MEAL_TYPES.includes(b.meal_type)) {
    errors.meal_type = `meal_type must be one of: ${MEAL_TYPES.join(', ')}`;
  }

  if (!b.started_at) {
    errors.started_at = 'started_at is required';
  } else if (isNaN(Date.parse(b.started_at))) {
    errors.started_at = 'started_at must be a valid ISO date string';
  }

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }

  next();
};

export const validateUpdateMeal = (req, res, next) => {
  const b = req.body || {};
  const errors = {};

  if (b.meal_type !== undefined && !MEAL_TYPES.includes(b.meal_type)) {
    errors.meal_type = `meal_type must be one of: ${MEAL_TYPES.join(', ')}`;
  }

  if (b.ended_at !== undefined && b.ended_at !== null) {
    if (isNaN(Date.parse(b.ended_at))) {
      errors.ended_at = 'ended_at must be a valid ISO date string';
    }
  }

  if (b.total_bites !== undefined) {
    if (typeof b.total_bites !== 'number' || b.total_bites < 0) {
      errors.total_bites = 'total_bites must be a non-negative number';
    }
  }

  if (b.avg_pace_bpm !== undefined && b.avg_pace_bpm !== null) {
    if (typeof b.avg_pace_bpm !== 'number' || b.avg_pace_bpm < 0) {
      errors.avg_pace_bpm = 'avg_pace_bpm must be a non-negative number';
    }
  }

  if (b.duration_minutes !== undefined && b.duration_minutes !== null) {
    if (typeof b.duration_minutes !== 'number' || b.duration_minutes < 0) {
      errors.duration_minutes = 'duration_minutes must be a non-negative number';
    }
  }

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }

  next();
};

// ─── Bites sync ───────────────────────────────────────────────────────────────

/**
 * Validates the bites array sent during mobile sync.
 * Each bite must have a timestamp; all other fields are optional numerics.
 */
export const validateSyncBites = (req, res, next) => {
  const { bites } = req.body || {};
  const errors = {};

  if (!Array.isArray(bites) || bites.length === 0) {
    return res.status(400).json({ message: 'Validation failed', errors: { bites: 'bites must be a non-empty array' } });
  }

  if (bites.length > 500) {
    return res.status(400).json({ message: 'Validation failed', errors: { bites: 'bites batch cannot exceed 500 items' } });
  }

  for (let i = 0; i < bites.length; i++) {
    const bite = bites[i];
    if (!bite.timestamp || isNaN(Date.parse(bite.timestamp))) {
      errors[`bites[${i}].timestamp`] = 'timestamp must be a valid ISO date string';
    }
    if (bite.tremor_magnitude !== undefined && bite.tremor_magnitude !== null) {
      if (typeof bite.tremor_magnitude !== 'number') {
        errors[`bites[${i}].tremor_magnitude`] = 'tremor_magnitude must be a number';
      }
    }
    if (bite.tremor_frequency !== undefined && bite.tremor_frequency !== null) {
      if (typeof bite.tremor_frequency !== 'number') {
        errors[`bites[${i}].tremor_frequency`] = 'tremor_frequency must be a number';
      }
    }
    if (bite.food_temp_c !== undefined && bite.food_temp_c !== null) {
      if (typeof bite.food_temp_c !== 'number') {
        errors[`bites[${i}].food_temp_c`] = 'food_temp_c must be a number';
      }
    }
  }

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }

  next();
};

// ─── Device registration ──────────────────────────────────────────────────────

export const validateRegisterDevice = (req, res, next) => {
  const b = req.body || {};
  const errors = {};

  if (!b.macAddressHash || typeof b.macAddressHash !== 'string') {
    errors.macAddressHash = 'macAddressHash is required and must be a string';
  } else if (b.macAddressHash.trim().length < 8) {
    errors.macAddressHash = 'macAddressHash appears too short to be valid';
  }

  if (b.heaterMaxTemp !== undefined && b.heaterMaxTemp !== null) {
    const temp = Number(b.heaterMaxTemp);
    if (isNaN(temp) || temp < 30 || temp > 80) {
      errors.heaterMaxTemp = 'heaterMaxTemp must be a number between 30 and 80';
    }
  }

  if (Object.keys(errors).length > 0) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }

  next();
};
