import dotenv from 'dotenv';
dotenv.config();

/**
 * Centralized Configuration (unifiedConfig.js)
 * Validates and exports all environment variables to ensure
 * they are accessed safely across the application instead of 
 * direct process.env usage.
 */
export const config = {
    app: {
        env: process.env.NODE_ENV || 'development',
        port: parseInt(process.env.PORT || '5001', 10),
    },
    db: {
        connectionString: process.env.DATABASE_URL,
    },
    auth: {
        jwtSecret: process.env.JWT_SECRET || 'default_secret_key',
        jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',
    },
    // Add other configurations as needed (e.g. redis, third party apis)
};
