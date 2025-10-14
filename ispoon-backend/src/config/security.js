// Security configuration constants and utilities
export const SECURITY_CONFIG = {
  // Rate limiting
  RATE_LIMITS: {
    AUTH: { windowMs: 15 * 60 * 1000, max: 5 }, // 5 auth attempts per 15 min
    GENERAL: { windowMs: 15 * 60 * 1000, max: 100 }, // 100 requests per 15 min
    RESET: { windowMs: 60 * 60 * 1000, max: 3 }, // 3 resets per hour
  },

  // Password requirements
  PASSWORD: {
    MIN_LENGTH: 8,
    MAX_LENGTH: 128,
    REQUIRE_UPPER: true,
    REQUIRE_LOWER: true,
    REQUIRE_NUMBER: true,
    REQUIRE_SPECIAL: true,
  },

  // Input limits
  INPUT_LIMITS: {
    EMAIL_MAX_LENGTH: 254,
    NAME_MAX_LENGTH: 100,
    PHONE_MAX_LENGTH: 20,
    LOCATION_MAX_LENGTH: 200,
    BIO_MAX_LENGTH: 500,
    EMERGENCY_CONTACT_MAX_LENGTH: 100,
    ALLERGIES_MAX_COUNT: 20,
    DAILY_GOAL_MAX: 10000,
  },

  // Session/JWT
  JWT: {
    SECRET_MIN_LENGTH: 32,
    EXPIRES_IN: '7d',
    ISSUER: 'i-spoon-backend',
    AUDIENCE: 'i-spoon-mobile',
  },

  // CORS allowed origins (for production)
  ALLOWED_ORIGINS: process.env.NODE_ENV === 'production'
    ? ['https://yourdomain.com', 'https://www.yourdomain.com']
    : ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://10.0.2.2:3000'],
};

// Security utilities
export const validateSecurityConfig = () => {
  const config = SECURITY_CONFIG;

  // Validate JWT secret length
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < config.JWT.SECRET_MIN_LENGTH) {
    throw new Error(`JWT_SECRET must be at least ${config.JWT.SECRET_MIN_LENGTH} characters`);
  }

  // Validate database URL
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required');
  }

  return true;
};

// Log security events (implement proper logging later)
export const logSecurityEvent = (event, details = {}) => {
  console.warn(`Security Event: ${event}`, details);
};
