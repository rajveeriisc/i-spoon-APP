export const validateUpdateMe = (req, res, next) => {
  const b = req.body || {};
  const errors = {};
  if (b.name !== undefined && typeof b.name !== 'string') errors.name = 'name must be string';
  if (b.phone !== undefined && typeof b.phone !== 'string') errors.phone = 'phone must be string';
  if (b.location !== undefined && typeof b.location !== 'string') errors.location = 'location must be string';
  if (b.bio !== undefined && typeof b.bio !== 'string') errors.bio = 'bio must be string';
  if (b.diet_type !== undefined && typeof b.diet_type !== 'string') errors.diet_type = 'diet_type must be string';
  if (b.activity_level !== undefined && typeof b.activity_level !== 'string') errors.activity_level = 'activity_level must be string';
  if (b.allergies !== undefined && !Array.isArray(b.allergies)) errors.allergies = 'allergies must be array';
  if (b.daily_goal !== undefined && typeof b.daily_goal !== 'number') errors.daily_goal = 'daily_goal must be number';
  if (b.notifications_enabled !== undefined && typeof b.notifications_enabled !== 'boolean') errors.notifications_enabled = 'notifications_enabled must be boolean';
  if (b.emergency_contact !== undefined && typeof b.emergency_contact !== 'string') errors.emergency_contact = 'emergency_contact must be string';
  if (Object.keys(errors).length) {
    return res.status(400).json({ message: 'Validation failed', errors });
  }
  next();
};


