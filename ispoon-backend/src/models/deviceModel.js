import { pool } from "../config/db.js";

/**
 * Create or Update a Device (Upsert based on MAC address)
 * Also handles Heater preferences and firmware version tracking.
 */
export const registerDevice = async ({
  userId,
  macAddressHash,
  firmwareVersion = null,
  heaterActive = false,
  heaterMaxTemp = 40.0,
}) => {
  const result = await pool.query(
    `
      INSERT INTO devices (
        user_id,
        mac_address_hash,
        firmware_version,
        heater_active,
        heater_max_temp,
        last_sync_at
      )
      VALUES ($1, $2, $3, $4, $5, NOW())
      ON CONFLICT (mac_address_hash)
      DO UPDATE SET
        -- Only update user_id if the device already belongs to this user.
        -- This prevents a device ownership takeover attack where an attacker
        -- registers a known MAC hash to steal the device from the real owner.
        user_id = CASE WHEN devices.user_id = $1 THEN $1 ELSE devices.user_id END,
        firmware_version = COALESCE(EXCLUDED.firmware_version, devices.firmware_version),
        heater_active = COALESCE(EXCLUDED.heater_active, devices.heater_active),
        heater_max_temp = COALESCE(EXCLUDED.heater_max_temp, devices.heater_max_temp),
        last_sync_at = NOW(),
        updated_at = NOW()
      RETURNING *
    `,
    [userId, macAddressHash, firmwareVersion, heaterActive, heaterMaxTemp]
  );

  return result.rows[0];
};

/**
 * Get all active devices for a user.
 */
export const getUserDevices = async (userId) => {
  const result = await pool.query(
    `
      SELECT 
        id,
        user_id,
        mac_address_hash,
        firmware_version,
        heater_active,
        heater_max_temp,
        last_sync_at
      FROM devices
      WHERE user_id = $1
      ORDER BY last_sync_at DESC
    `,
    [userId]
  );
  return result.rows;
};

/**
 * Update device settings (heater control).
 */
export const updateDeviceSettings = async ({
  userId,
  deviceId,
  heaterActive,
  heaterMaxTemp,
}) => {
  const result = await pool.query(
    `
      UPDATE devices
      SET
        heater_active = COALESCE($3, heater_active),
        heater_max_temp = COALESCE($4, heater_max_temp),
        updated_at = NOW()
      WHERE id = $2 AND user_id = $1
      RETURNING *
    `,
    [userId, deviceId, heaterActive, heaterMaxTemp]
  );
  return result.rows[0];
};

