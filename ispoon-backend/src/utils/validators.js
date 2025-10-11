export const sanitizeEmail = (email) => (email || "").trim().toLowerCase();

export const isValidEmail = (email) => {
  if (!email) return false;
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/i;
  return re.test(email.trim());
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


