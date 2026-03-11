/**
 * asyncHandler — eliminates repetitive try/catch blocks in Express route handlers.
 *
 * Wraps an async controller function and forwards any thrown error to Express's
 * `next(err)` so the global errorMiddleware handles it centrally.
 *
 * Usage:
 *   router.get('/path', asyncHandler(async (req, res) => {
 *     const data = await someAsyncOperation();
 *     res.json({ data });
 *   }));
 *
 * @param {Function} fn - async Express handler (req, res, next) => Promise<void>
 * @returns {Function} wrapped handler that catches rejections
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

export default asyncHandler;
