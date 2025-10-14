// Input sanitization functions
export const sanitizeEmail = (email) => {
  if (!email || typeof email !== 'string') return '';
  return email.trim().toLowerCase().slice(0, 254); // Max email length
};

export const sanitizeString = (str, maxLength = 1000) => {
  if (!str || typeof str !== 'string') return '';
  return str.trim().slice(0, maxLength);
};

export const sanitizeNumber = (num, min = 0, max = 999999) => {
  if (typeof num !== 'number' || isNaN(num)) return null;
  return Math.max(min, Math.min(max, Math.round(num)));
};

export const sanitizeBoolean = (bool) => {
  if (typeof bool === 'boolean') return bool;
  if (typeof bool === 'string') {
    const lower = bool.toLowerCase().trim();
    return lower === 'true' || lower === '1';
  }
  return Boolean(bool);
};

export const sanitizeArray = (arr, maxLength = 100) => {
  if (!Array.isArray(arr)) return [];
  return arr.slice(0, maxLength).map(item =>
    typeof item === 'string' ? item.trim().slice(0, 100) : item
  );
};

export const isValidEmail = (email) => {
  if (!email || typeof email !== 'string') return false;
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/i;
  return re.test(email.trim()) && email.length <= 254;
};

export const isStrongPassword = (password) => {
  if (typeof password !== "string") return false;
  const minLength = password.length >= 8;
  const hasUpper = /[A-Z]/.test(password);
  const hasLower = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);
  return minLength && hasUpper && hasLower && hasNumber && hasSpecial;
};

export const validateSignup = ({ email, password }) => {
  const errors = {};
  if (!email) errors.email = "Email is required";
  else if (!isValidEmail(email)) errors.email = "Email is invalid";

  if (!password) errors.password = "Password is required";
  else if (!isStrongPassword(password))
    errors.password =
      "Password must be 8+ chars and include upper, lower, number, special";

  return { valid: Object.keys(errors).length === 0, errors };
};

export const validateLogin = ({ email, password }) => {
  const errors = {};
  if (!email) errors.email = "Email is required";
  else if (!isValidEmail(email)) errors.email = "Email is invalid";
  if (!password) errors.password = "Password is required";
  return { valid: Object.keys(errors).length === 0, errors };
};


