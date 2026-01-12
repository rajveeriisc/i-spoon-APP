import { pool } from "../config/db.js";

/**
 * Telemetry Repository
 * Handles high-frequency sensor data retrieval and device health monitoring
 */

// ============================================================================
// IMU SAMPLES (Accelerometer \u0026 Gyroscope)
// ============================================================================

/**
 * Get IMU samples for a device session
 * @param {number} deviceSessionId - Device session ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>} Array of IMU samples
 */
export const getImuSamples = async (deviceSessionId, {
    startTime = null,
    endTime = null,
    limit = 1000,
    offset = 0,
} = {}) => {
    let query = `
    SELECT * FROM imu_samples
    WHERE device_session_id = $1
  `;
    const params = [deviceSessionId];
    let paramIndex = 2;

    if (startTime) {
        query += ` AND recorded_at >= $${paramIndex++}`;
        params.push(startTime);
    }

    if (endTime) {
        query += ` AND recorded_at <= $${paramIndex++}`;
        params.push(endTime);
    }

    query += ` ORDER BY recorded_at ASC LIMIT $${paramIndex++} OFFSET $${paramIndex}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    return result.rows;
};

/**
 * Get aggregated IMU statistics
 * @param {number} deviceSessionId - Device session ID
 * @returns {Promise<Object>} Aggregated statistics
 */
export const getImuStatistics = async (deviceSessionId) => {
    const result = await pool.query(
        `SELECT
       COUNT(*) AS sample_count,
       AVG(accel_x) AS avg_accel_x,
       AVG(accel_y) AS avg_accel_y,
       AVG(accel_z) AS avg_accel_z,
       AVG(gyro_x) AS avg_gyro_x,
       AVG(gyro_y) AS avg_gyro_y,
       AVG(gyro_z) AS avg_gyro_z,
       AVG(temperature_c) AS avg_temperature_c,
       STDDEV(accel_x) AS stddev_accel_x,
       STDDEV(gyro_x) AS stddev_gyro_x
     FROM imu_samples
     WHERE device_session_id = $1`,
        [deviceSessionId]
    );
    return result.rows[0];
};

// ============================================================================
// TEMPERATURE SAMPLES
// ============================================================================

/**
 * Get temperature samples for a device session
 * @param {number} deviceSessionId - Device session ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>} Array of temperature samples
 */
export const getTemperatureSamples = async (deviceSessionId, {
    startTime = null,
    endTime = null,
    limit = 500,
} = {}) => {
    let query = `
    SELECT * FROM temperature_samples
    WHERE device_session_id = $1
  `;
    const params = [deviceSessionId];
    let paramIndex = 2;

    if (startTime) {
        query += ` AND recorded_at >= $${paramIndex++}`;
        params.push(startTime);
    }

    if (endTime) {
        query += ` AND recorded_at <= $${paramIndex++}`;
        params.push(endTime);
    }

    query += ` ORDER BY recorded_at ASC LIMIT $${paramIndex}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows;
};

/**
 * Get temperature statistics
 * @param {number} deviceSessionId - Device session ID
 * @returns {Promise<Object>} Temperature statistics
 */
export const getTemperatureStatistics = async (deviceSessionId) => {
    const result = await pool.query(
        `SELECT
       COUNT(*) AS sample_count,
       AVG(food_temp_c) AS avg_food_temp,
       MAX(food_temp_c) AS max_food_temp,
       MIN(food_temp_c) AS min_food_temp,
       AVG(heater_temp_c) AS avg_heater_temp,
       AVG(utensil_temp_c) AS avg_utensil_temp
     FROM temperature_samples
     WHERE device_session_id = $1`,
        [deviceSessionId]
    );
    return result.rows[0];
};

// ============================================================================
// TREMOR METRICS
// ============================================================================

/**
 * Get tremor metrics for a device session
 * @param {number} deviceSessionId - Device session ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>} Array of tremor metrics
 */
export const getTremorMetrics = async (deviceSessionId, {
    startTime = null,
    endTime = null,
    level = null,
    limit = 500,
} = {}) => {
    let query = `
    SELECT * FROM tremor_metrics
    WHERE device_session_id = $1
  `;
    const params = [deviceSessionId];
    let paramIndex = 2;

    if (startTime) {
        query += ` AND recorded_at >= $${paramIndex++}`;
        params.push(startTime);
    }

    if (endTime) {
        query += ` AND recorded_at <= $${paramIndex++}`;
        params.push(endTime);
    }

    if (level) {
        query += ` AND level = $${paramIndex++}`;
        params.push(level);
    }

    query += ` ORDER BY recorded_at ASC LIMIT $${paramIndex}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows;
};

/**
 * Get tremor statistics
 * @param {number} deviceSessionId - Device session ID
 * @returns {Promise<Object>} Tremor statistics
 */
export const getTremorStatistics = async (deviceSessionId) => {
    const result = await pool.query(
        `SELECT
       COUNT(*) AS sample_count,
       AVG(magnitude) AS avg_magnitude,
       MAX(magnitude) AS max_magnitude,
       MIN(magnitude) AS min_magnitude,
       AVG(peak_frequency_hz) AS avg_frequency,
       MODE() WITHIN GROUP (ORDER BY level) AS dominant_level
     FROM tremor_metrics
     WHERE device_session_id = $1`,
        [deviceSessionId]
    );
    return result.rows[0];
};

// ============================================================================
// ENVIRONMENT SAMPLES
// ============================================================================

/**
 * Get environment samples for a device session
 * @param {number} deviceSessionId - Device session ID
 * @param {Object} options - Query options
 * @returns {Promise<Array>} Array of environment samples
 */
export const getEnvironmentSamples = async (deviceSessionId, {
    startTime = null,
    endTime = null,
    limit = 500,
} = {}) => {
    let query = `
    SELECT * FROM environment_samples
    WHERE device_session_id = $1
  `;
    const params = [deviceSessionId];
    let paramIndex = 2;

    if (startTime) {
        query += ` AND recorded_at >= $${paramIndex++}`;
        params.push(startTime);
    }

    if (endTime) {
        query += ` AND recorded_at <= $${paramIndex++}`;
        params.push(endTime);
    }

    query += ` ORDER BY recorded_at ASC LIMIT $${paramIndex}`;
    params.push(limit);

    const result = await pool.query(query, params);
    return result.rows;
};

// ============================================================================
// DEVICE HEALTH
// ============================================================================

/**
 * Get device health snapshots
 * @param {number} userDeviceId - User device ID
 * @param {number} limit - Maximum number of snapshots
 * @returns {Promise<Array>} Array of health snapshots
 */
export const getDeviceHealthSnapshots = async (userDeviceId, limit = 100) => {
    const result = await pool.query(
        `SELECT * FROM device_health_snapshots
     WHERE user_device_id = $1
     ORDER BY recorded_at DESC
     LIMIT $2`,
        [userDeviceId, limit]
    );
    return result.rows;
};

/**
 * Get latest device health
 * @param {number} userDeviceId - User device ID
 * @returns {Promise<Object>} Latest health snapshot
 */
export const getLatestDeviceHealth = async (userDeviceId) => {
    const result = await pool.query(
        `SELECT * FROM device_health_snapshots
     WHERE user_device_id = $1
     ORDER BY recorded_at DESC
     LIMIT 1`,
        [userDeviceId]
    );
    return result.rows[0] || null;
};

// ============================================================================
// COMPREHENSIVE TELEMETRY
// ============================================================================

/**
 * Get all telemetry for a device session
 * @param {number} deviceSessionId - Device session ID
 * @returns {Promise<Object>} All telemetry data
 */
export const getComprehensiveTelemetry = async (deviceSessionId) => {
    const [imuStats, tempStats, tremorStats, imuSamples, tempSamples, tremorSamples] = await Promise.all([
        getImuStatistics(deviceSessionId),
        getTemperatureStatistics(deviceSessionId),
        getTremorStatistics(deviceSessionId),
        getImuSamples(deviceSessionId, { limit: 100 }), // Last 100 samples
        getTemperatureSamples(deviceSessionId, { limit: 50 }),
        getTremorMetrics(deviceSessionId, { limit: 50 }),
    ]);

    return {
        statistics: {
            imu: imuStats,
            temperature: tempStats,
            tremor: tremorStats,
        },
        recentSamples: {
            imu: imuSamples,
            temperature: tempSamples,
            tremor: tremorSamples,
        },
    };
};
