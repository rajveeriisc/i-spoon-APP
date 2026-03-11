import {
    registerDevice as registerDeviceModel,
    getUserDevices as getUserDevicesModel,
    updateDeviceSettings as updateDeviceSettingsModel,
} from "../models/deviceModel.js";

/**
 * DeviceService encapsulates the business logic for device operations.
 * It is called by the DeviceController and communicates with Models/Repositories.
 */
export default class DeviceService {

    /**
     * Retrieves all devices mapped to a specific user.
     */
    async getUserDevices(userId) {
        return await getUserDevicesModel(userId);
    }

    /**
     * Registers a new device or updates an existing device for a user.
     */
    async registerDevice(userId, data) {
        const deviceData = {
            userId,
            macAddressHash: data.macAddressHash,
            firmwareVersion: data.firmwareVersion,
            heaterActive: data.heaterActive,
            heaterMaxTemp: data.heaterMaxTemp,
        };

        return await registerDeviceModel(deviceData);
    }

    /**
     * Updates settings for a specific device owned by the user.
     */
    async updateSettings(userId, deviceId, data) {
        return await updateDeviceSettingsModel({
            userId,
            deviceId,
            heaterActive: data.heaterActive,
            heaterMaxTemp: data.heaterMaxTemp,
        });
    }
}
