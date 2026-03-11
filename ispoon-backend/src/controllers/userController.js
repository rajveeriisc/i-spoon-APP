import UserService from "../services/userService.js";
import BaseController from "./BaseController.js";
import asyncHandler from "../utils/asyncHandler.js";
import logger from "../utils/logger.js";
import { AppError } from "../utils/errors.js";

class UserController extends BaseController {
  constructor() {
    super();
  }

  getMe = asyncHandler(async (req, res) => {
    const userId = req.user?.id;
    if (!userId) throw new AppError('Unauthorized', 401);

    const user = await UserService.getMe(userId);
    this.handleSuccess(res, { user });
  });

  updateMe = asyncHandler(async (req, res) => {
    const userId = req.user?.id;
    if (!userId) throw new AppError('Unauthorized', 401);

    const updated = await UserService.updateMe(userId, req.body);
    logger.info('User profile updated', { requestId: req.id, userId });
    this.handleSuccess(res, { message: "Profile updated", user: updated });
  });

  uploadAvatar = asyncHandler(async (req, res) => {
    const userId = req.user?.id;
    if (!userId) throw new AppError('Unauthorized', 401);

    const updated = await UserService.uploadAvatar(userId, req.processedFile);
    logger.info('Avatar updated', { requestId: req.id, userId });
    this.handleSuccess(res, { message: "Avatar updated and optimized", user: updated });
  });

  removeAvatar = asyncHandler(async (req, res) => {
    const userId = req.user?.id;
    if (!userId) throw new AppError('Unauthorized', 401);

    const updated = await UserService.removeAvatar(userId);
    this.handleSuccess(res, { message: "Avatar removed", user: updated });
  });
}

export default new UserController();
