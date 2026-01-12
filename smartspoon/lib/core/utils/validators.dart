final _emailRegex = RegExp(r'^\S+@\S+\.\S+$');
final _passwordUppercase = RegExp(r'[A-Z]');
final _passwordLowercase = RegExp(r'[a-z]');
final _passwordNumber = RegExp(r'[0-9]');
final _passwordSpecial = RegExp(r'[^A-Za-z0-9]');

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email';
  }
  final normalized = value.trim();
  if (!_emailRegex.hasMatch(normalized)) {
    return 'Please enter a valid email address';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!_passwordUppercase.hasMatch(value)) {
    return 'Password must contain at least one uppercase letter';
  }
  if (!_passwordLowercase.hasMatch(value)) {
    return 'Password must contain at least one lowercase letter';
  }
  if (!_passwordNumber.hasMatch(value)) {
    return 'Password must contain at least one number';
  }
  if (!_passwordSpecial.hasMatch(value)) {
    return 'Password must contain at least one special character';
  }
  return null;
}

String? validateConfirmPassword(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != password) {
    return 'Passwords do not match';
  }
  return null;
}
