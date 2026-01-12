import express from 'express';
import { triggerMockDataGeneration } from '../services/mockData.service.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

/**
 * Mock Data Routes
 * For development/testing purposes - generates realistic test data
 */

/**
 * @route   POST /api/mock/generate
 * @desc    Generate mock session data (temperature, IMU, tremor, meal)
 * @access  Private
 * @body    {
 *            duration: number (minutes, default 30),
 *            includeMeal: boolean (default true),
 *            tremorLevel: 'low' | 'moderate' | 'high' (default 'low')
 *          }
 */
router.post('/generate', protect, triggerMockDataGeneration);

export default router;
