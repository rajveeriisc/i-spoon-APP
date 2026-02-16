import { pool } from "../config/db.js";

/**
 * Create or update a firmware version entry.
 * When hardware revision is omitted it is treated as a global firmware build.
 */
export const upsertFirmwareVersion = async ({
  version,
  hardwareRevision = null,
  checksum = null,
  releaseNotes = null,
  releasedAt = null,
}) => {
  const result = await pool.query(
    `
      INSERT INTO firmware_versions (version, hardware_revision, checksum, release_notes, released_at)
      VALUES ($1, $2, $3, $4, COALESCE($5, NOW()))
      ON CONFLICT (version, hardware_revision)
      DO UPDATE SET
        checksum = EXCLUDED.checksum,
        release_notes = EXCLUDED.release_notes,
        released_at = EXCLUDED.released_at,
        updated_at = NOW()
      RETURNING *
    `,
    [version, hardwareRevision, checksum, releaseNotes, releasedAt]
  );

  return result.rows[0];
};

/**
 * Create a physical device record.
 * Serial number is expected to be globally unique.
 */
export const createDevice = async ({
  serialNumber,
  bleIdentifier = null,
  hardwareRevision = null,
  firmwareVersionId = null,
  manufacturedAt = null,
  status = "active",
}) => {
  const result = await pool.query(
    `
      INSERT INTO devices (
        serial_number,
        ble_identifier,
        hardware_revision,
        firmware_version_id,
        manufactured_at,
        status
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (serial_number)
      DO UPDATE SET
        ble_identifier = COALESCE(EXCLUDED.ble_identifier, devices.ble_identifier),
        hardware_revision = COALESCE(EXCLUDED.hardware_revision, devices.hardware_revision),
        firmware_version_id = COALESCE(EXCLUDED.firmware_version_id, devices.firmware_version_id),
        manufactured_at = COALESCE(EXCLUDED.manufactured_at, devices.manufactured_at),
        status = EXCLUDED.status,
        updated_at = NOW()
      RETURNING *
    `,
    [serialNumber, bleIdentifier, hardwareRevision, firmwareVersionId, manufacturedAt, status]
  );

  return result.rows[0];
};

/**
 * Link a device to a specific user account.
 */
export const linkDeviceToUser = async ({
  userId,
  deviceId,
  nickname = null,
  autoConnect = false,
  isPrimary = false,
}) => {
  const result = await pool.query(
    `
      INSERT INTO user_devices (
        user_id,
        device_id,
        nickname,
        auto_connect,
        is_primary
      )
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (user_id, device_id)
      DO UPDATE SET
        nickname = COALESCE(EXCLUDED.nickname, user_devices.nickname),
        auto_connect = EXCLUDED.auto_connect,
        is_primary = EXCLUDED.is_primary,
        revoked_at = NULL,
        updated_at = NOW()
      RETURNING *
    `,
    [userId, deviceId, nickname, autoConnect, isPrimary]
  );

  return result.rows[0];
};

/**
 * Soft revoke a user/device pairing.
 */
export const revokeUserDevice = async ({ userDeviceId, revokedAt = null }) => {
  const result = await pool.query(
    `
      UPDATE user_devices
      SET revoked_at = COALESCE($2, NOW()), updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `,
    [userDeviceId, revokedAt]
  );

  return result.rows[0];
};

/**
 * Create a new device session row when telemetry recording begins.
 */
export const createDeviceSession = async ({
  userDeviceId,
  authSessionId = null,
  firmwareVersionId = null,
  startedAt = null,
  startBatteryPercent = null,
  connectionType = null,
  appVersion = null,
  locationHint = null,
  notes = null,
}) => {
  const result = await pool.query(
    `
      INSERT INTO device_sessions (
        user_device_id,
        auth_session_id,
        firmware_version_id,
        started_at,
        start_battery_percent,
        connection_type,
        app_version,
        location_hint,
        notes
      )
      VALUES ($1, $2, COALESCE($3, (
          SELECT devices.firmware_version_id
          FROM user_devices
          JOIN devices ON user_devices.device_id = devices.id
          WHERE user_devices.id = $1
        )),
        COALESCE($4, NOW()),
        $5,
        $6,
        $7,
        $8,
        $9
      )
      RETURNING *
    `,
    [
      userDeviceId,
      authSessionId,
      firmwareVersionId,
      startedAt,
      startBatteryPercent,
      connectionType,
      appVersion,
      locationHint,
      notes,
    ]
  );

  return result.rows[0];
};

export const completeDeviceSession = async ({
  deviceSessionId,
  endedAt = null,
  endBatteryPercent = null,
  notes = null,
}) => {
  const result = await pool.query(
    `
      UPDATE device_sessions
      SET
        ended_at = COALESCE($2, NOW()),
        end_battery_percent = COALESCE($3, end_battery_percent),
        notes = COALESCE($4, notes),
        updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `,
    [deviceSessionId, endedAt, endBatteryPercent, notes]
  );

  return result.rows[0];
};

export const recordDeviceHealthSnapshot = async ({
  userDeviceId,
  deviceSessionId = null,
  recordedAt = null,
  batteryPercent = null,
  voltage = null,
  chargeCycles = null,
  sensorsHealthy = null,
  faultCode = null,
  cpuTempC = null,
}) => {
  const result = await pool.query(
    `
      INSERT INTO device_health_snapshots (
        user_device_id,
        device_session_id,
        recorded_at,
        battery_percent,
        voltage,
        charge_cycles,
        sensors_healthy,
        fault_code,
        cpu_temp_c
      )
      VALUES ($1, $2, COALESCE($3, NOW()), $4, $5, $6, $7, $8, $9)
      RETURNING *
    `,
    [
      userDeviceId,
      deviceSessionId,
      recordedAt,
      batteryPercent,
      voltage,
      chargeCycles,
      sensorsHealthy,
      faultCode,
      cpuTempC,
    ]
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
        ud.id,
        ud.user_id,
        ud.device_id,
        ud.nickname,
        ud.auto_connect,
        ud.is_primary,
        ud.heater_active,
        ud.heater_activation_temp,
        ud.heater_max_temp,
        d.serial_number,
        d.ble_identifier,
        d.hardware_revision,
        d.firmware_version_id,
        d.status,
        fv.version as firmware_version
      FROM user_devices ud
      JOIN devices d ON ud.device_id = d.id
      LEFT JOIN firmware_versions fv ON d.firmware_version_id = fv.id
      WHERE ud.user_id = $1 AND ud.revoked_at IS NULL
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
  userDeviceId,
  heaterActive,
  heaterActivationTemp,
  heaterMaxTemp,
}) => {
  const result = await pool.query(
    `
      UPDATE user_devices
      SET
        heater_active = COALESCE($3, heater_active),
        heater_activation_temp = COALESCE($4, heater_activation_temp),
        heater_max_temp = COALESCE($5, heater_max_temp),
        updated_at = NOW()
      WHERE id = $2 AND user_id = $1
      RETURNING *
    `,
    [userId, userDeviceId, heaterActive, heaterActivationTemp, heaterMaxTemp]
  );
  return result.rows[0];
};

