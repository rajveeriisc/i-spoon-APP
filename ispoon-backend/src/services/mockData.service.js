import { pool } from '../config/db.js';

/**
 * Mock Data Generator (Simplified Version)
 * Generates realistic test data for SmartSpoon when physical device is not connected
 */

/**
 * Generate realistic temperature reading
 */
const generateTemperature = (type, baseTemp, variance = 5) => {
    const random = (Math.random() - 0.5) * 2 * variance;
    let temp = baseTemp + random;

    if (type === 'food') {
        temp = Math.max(10, Math.min(80, temp));
    } else if (type === 'heater') {
        temp = Math.max(40, Math.min(100, temp));
    }

    return parseFloat(temp.toFixed(2));
};

/**
 * API endpoint to trigger mock data generation
 */
export const triggerMockDataGeneration = async (req, res) => {
    try {
        const userId = req.user?.id;

        if (!userId) {
            return res.status(401).json({ message: 'Unauthorized' });
        }

        // Get user's primary device
        const deviceResult = await pool.query(
            `SELECT id FROM user_devices 
       WHERE user_id = $1 AND is_primary = TRUE AND revoked_at IS NULL 
       LIMIT 1`,
            [userId]
        );

        if (deviceResult.rows.length === 0) {
            return res.status(404).json({
                message: 'No paired device found. Please pair a device first.'
            });
        }

        const userDeviceId = deviceResult.rows[0].id;
        const duration = parseInt(req.body.duration) || 30;
        const tremorLevel = req.body.tremorLevel || 'low';

        // Create device session
        const sessionResult = await pool.query(
            `INSERT INTO device_sessions (
        user_device_id, started_at, start_battery_percent, connection_type
      ) VALUES ($1, NOW(), $2, 'BLE') RETURNING id`,
            [userDeviceId, Math.round(Math.random() * 30 + 70)]
        );

        const sessionId = sessionResult.rows[0].id;

        // Generate temperature samples (simplified - just insert a few samples)
        const tempSamples = [];
        for (let i = 0; i < 10; i++) {
            const foodTemp = generateTemperature('food', 45 - i, 3);
            const heaterTemp = generateTemperature('heater', 70 + i * 0.5, 4);
            tempSamples.push(`(${sessionId}, NOW() + INTERVAL '${i} seconds', ${foodTemp}, ${heaterTemp}, 25.0)`);
        }

        if (tempSamples.length > 0) {
            await pool.query(`
        INSERT INTO temperature_samples (device_session_id, recorded_at, food_temp_c, heater_temp_c, utensil_temp_c)
        VALUES ${tempSamples.join(', ')}
      `);
        }

        console.log(`✅ Generated ${tempSamples.length} temperature samples for session ${sessionId}`);

        res.json({
            success: true,
            message: 'Mock data generated successfully',
            data: {
                sessionId,
                duration: `${duration} minutes`,
                tremorLevel,
                samplesGenerated: tempSamples.length,
            },
        });
    } catch (error) {
        console.error('Error generating mock data:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to generate mock data',
            error: error.message,
        });
    }
};
