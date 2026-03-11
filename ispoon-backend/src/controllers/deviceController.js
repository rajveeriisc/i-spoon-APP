import BaseController from './BaseController.js';
import DeviceService from '../services/deviceService.js';
import { AppError } from '../utils/errors.js';
import logger from '../utils/logger.js';
import asyncHandler from '../utils/asyncHandler.js';

/**
 * DeviceController handles the request/response lifecycle for devices,
 * delegating business logic to the injected DeviceService.
 */
class DeviceController extends BaseController {
  constructor(deviceService) {
    super();
    this.deviceService = deviceService;
  }

  getUserDevices = asyncHandler(async (req, res, next) => {
    try {
      const userId = req.user?.id;
      if (!userId) throw new AppError('Unauthorized', 401);

      const devices = await this.deviceService.getUserDevices(userId);
      this.handleSuccess(res, devices, 'User devices retrieved');
    } catch (error) {
      this.handleError(error, req, next, 'DeviceController.getUserDevices');
    }
  });

  registerDevice = asyncHandler(async (req, res, next) => {
    try {
      // Input is already validated and sanitized by Zod via validateRequest middleware
      const userId = req.user?.id;
      if (!userId) throw new AppError('Unauthorized', 401);

      const device = await this.deviceService.registerDevice(userId, req.body);

      logger.info('Device registered', { requestId: req.id, userId, deviceId: device.id });
      this.handleSuccess(res, device, 'Device registered and synced', 201);
    } catch (error) {
      this.handleError(error, req, next, 'DeviceController.registerDevice');
    }
  });

  updateSettings = asyncHandler(async (req, res, next) => {
    try {
      // Input is already validated and sanitized by Zod
      const userId = req.user?.id;
      const { deviceId } = req.params;

      if (!userId) throw new AppError('Unauthorized', 401);
      if (!deviceId) throw new AppError('deviceId is required', 400);

      const updated = await this.deviceService.updateSettings(userId, deviceId, req.body);

      if (!updated) throw new AppError('Device not found or not owned by user', 404);

      logger.info('Device settings updated', { requestId: req.id, userId, deviceId });
      this.handleSuccess(res, updated, 'Settings updated');
    } catch (error) {
      this.handleError(error, req, next, 'DeviceController.updateSettings');
    }
  });
}

// Export a singleton instance with dependencies injected
export default new DeviceController(new DeviceService());
