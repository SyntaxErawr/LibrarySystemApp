import 'dart:convert';

class AuthValidation {
  static const programs = ['BSIT', 'BSCS', 'BSBA', 'BSHM', 'Other'];
  static const years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  static String? email(String? value) {
    final text = (value ?? '').trim();
    return text.length <= 254 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }

  static Map<String, bool> passwordChecks(String value) => {
    'At least 8 characters': value.runes.length >= 8,
    'One uppercase letter (A–Z)': RegExp('[A-Z]').hasMatch(value),
    'One lowercase letter (a–z)': RegExp('[a-z]').hasMatch(value),
    'One number (0–9)': RegExp('[0-9]').hasMatch(value),
    'One special character': RegExp(
      r'[^\p{L}\p{N}\s]',
      unicode: true,
    ).hasMatch(value),
    'At most 72 UTF-8 bytes': utf8.encode(value).length <= 72,
  };

  static String? loginPassword(String? value) =>
      value != null && value.isNotEmpty && utf8.encode(value).length <= 72
      ? null
      : 'Enter your password (maximum 72 UTF-8 bytes).';

  static Map<String, String> registration(Map<String, String> values) {
    final errors = <String, String>{};
    void text(String key, String label, int max) {
      final value = (values[key] ?? '').trim();
      if (value.isEmpty) {
        errors[key] = '$label is required.';
      } else if (value.length > max) {
        errors[key] = 'Use at most $max characters.';
      }
    }

    text('name', 'Full name', 100);
    text('studentId', 'School ID', 50);
    final emailError = email(values['email']);
    if (emailError != null) errors['email'] = emailError;
    if (!programs.contains(values['course'])) {
      errors['course'] = 'Select a course / program.';
    }
    if (values['course'] == 'Other') {
      text('otherProgram', 'Course / program', 100);
    }
    if (!years.contains(values['yearLevel'])) {
      errors['yearLevel'] = 'Select a year level.';
    }
    final password = values['password'] ?? '';
    if (password.trim().isEmpty ||
        passwordChecks(password).values.any((ok) => !ok)) {
      errors['password'] = 'Meet all password requirements.';
    }
    if ((values['confirmPassword'] ?? '').isEmpty ||
        password != values['confirmPassword']) {
      errors['confirmPassword'] = 'Passwords must match and cannot be empty.';
    }
    return errors;
  }
}
