import {
  createDevice,
  createDeviceSession,
  completeDeviceSession,
  linkDeviceToUser,
  recordDeviceHealthSnapshot,
  upsertFirmwareVersion,
  updateDeviceSettings,
  getUserDevices as getUserDevicesModel,
} from "../models/deviceModel.js";

// ... existing imports

// ... existing code ...

export const getUserDevices = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const devices = await getUserDevicesModel(userId);

    res.json({
      message: "User devices retrieved",
      devices,
    });
  } catch (error) {
    next(error);
  }
};


const parseIntOrNull = (value) => {
  const n = Number(value);
  return Number.isNaN(n) ? null : n;
};

const parseBoolean = (value) => {
  if (value === null || value === undefined) return null;
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true") return true;
    if (normalized === "false") return false;
  }
  return Boolean(value);
};

export const registerDevice = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const {
      serialNumber,
      bleIdentifier,
      hardwareRevision,
      firmwareVersion,
      firmwareChecksum,
      firmwareReleaseNotes,
      firmwareReleasedAt,
      autoConnect = false,
      isPrimary = false,
      nickname = null,
      manufacturedAt = null,
    } = req.body || {};

    if (!serialNumber) {
      return res.status(400).json({ message: "serialNumber is required" });
    }

    let firmwareVersionId = null;
    if (firmwareVersion) {
      const firmwareRow = await upsertFirmwareVersion({
        version: firmwareVersion,
        hardwareRevision,
        checksum: firmwareChecksum,
        releaseNotes: firmwareReleaseNotes,
        releasedAt: firmwareReleasedAt,
      });
      firmwareVersionId = firmwareRow?.id ?? null;
    }

    const device = await createDevice({
      serialNumber,
      bleIdentifier,
      hardwareRevision,
      firmwareVersionId,
      manufacturedAt,
      status: "active",
    });

    const userDevice = await linkDeviceToUser({
      userId,
      deviceId: device.id,
      nickname,
      autoConnect: parseBoolean(autoConnect) ?? false,
      isPrimary: parseBoolean(isPrimary) ?? false,
    });

    res.status(201).json({
      message: "Device registered",
      device,
      userDevice,
    });
  } catch (error) {
    next(error);
  }
};

export const startDeviceSession = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const {
      userDeviceId,
      authSessionId = null,
      firmwareVersionId = null,
      startedAt = null,
      startBatteryPercent = null,
      connectionType = null,
      appVersion = null,
      locationHint = null,
      notes = null,
    } = req.body || {};

    if (!userDeviceId) {
      return res.status(400).json({ message: "userDeviceId is required" });
    }

    const session = await createDeviceSession({
      userDeviceId: parseInt(userDeviceId, 10),
      authSessionId: authSessionId ? parseInt(authSessionId, 10) : null,
      firmwareVersionId: firmwareVersionId ? parseInt(firmwareVersionId, 10) : null,
      startedAt,
      startBatteryPercent: startBatteryPercent != null ? parseIntOrNull(startBatteryPercent) : null,
      connectionType,
      appVersion,
      locationHint,
      notes,
    });

    res.status(201).json({
      message: "Device session started",
      session,
    });
  } catch (error) {
    next(error);
  }
};

export const finishDeviceSession = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { sessionId } = req.params;
    const { endedAt = null, endBatteryPercent = null, notes = null } = req.body || {};

    if (!sessionId) {
      return res.status(400).json({ message: "sessionId is required" });
    }

    const session = await completeDeviceSession({
      deviceSessionId: parseInt(sessionId, 10),
      endedAt,
      endBatteryPercent: endBatteryPercent != null ? parseIntOrNull(endBatteryPercent) : null,
      notes,
    });

    res.json({
      message: "Device session completed",
      session,
    });
  } catch (error) {
    next(error);
  }
};

export const recordHealth = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const {
      userDeviceId,
      deviceSessionId = null,
      recordedAt = null,
      batteryPercent = null,
      voltage = null,
      chargeCycles = null,
      sensorsHealthy = null,
      faultCode = null,
      cpuTempC = null,
    } = req.body || {};

    if (!userDeviceId) {
      return res.status(400).json({ message: "userDeviceId is required" });
    }

    const snapshot = await recordDeviceHealthSnapshot({
      userDeviceId: parseInt(userDeviceId, 10),
      deviceSessionId: deviceSessionId ? parseInt(deviceSessionId, 10) : null,
      recordedAt,
      batteryPercent: batteryPercent != null ? parseIntOrNull(batteryPercent) : null,
      voltage: voltage != null ? Number(voltage) : null,
      chargeCycles: chargeCycles != null ? parseIntOrNull(chargeCycles) : null,
      sensorsHealthy: parseBoolean(sensorsHealthy),
      faultCode,
      cpuTempC: cpuTempC != null ? Number(cpuTempC) : null,
    });

    res.status(201).json({
      message: "Device health snapshot recorded",
      snapshot,
    });
  } catch (error) {
    next(error);
  }
};

export const updateSettings = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { userDeviceId } = req.params;
    const {
      heaterActive,
      heaterActivationTemp,
      heaterMaxTemp,
    } = req.body;

    if (!userDeviceId) {
      return res.status(400).json({ message: "userDeviceId is required" });
    }

    const updated = await updateDeviceSettings({
      userId,
      userDeviceId: parseInt(userDeviceId, 10),
      heaterActive: parseBoolean(heaterActive),
      heaterActivationTemp: heaterActivationTemp != null ? Number(heaterActivationTemp) : null,
      heaterMaxTemp: heaterMaxTemp != null ? Number(heaterMaxTemp) : null,
    });

    if (!updated) {
      return res.status(404).json({ message: "Device not found or not owned by user" });
    }

    res.json({
      message: "Settings updated",
      settings: updated,
    });
  } catch (error) {
    next(error);
  }
};

