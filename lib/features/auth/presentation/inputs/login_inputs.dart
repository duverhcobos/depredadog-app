import 'package:formz/formz.dart';

/// SOLID (SRP): cada input conoce su propia regla de validación — la UI solo
/// lee `displayError`, nunca valida en el widget.
enum EmailValidationError { invalid, empty }

final class EmailInput extends FormzInput<String, EmailValidationError> {
  const EmailInput.pure() : super.pure('');
  const EmailInput.dirty([super.value = '']) : super.dirty();

  static final _regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  EmailValidationError? validator(String value) {
    if (value.trim().isEmpty) return EmailValidationError.empty;
    if (!_regex.hasMatch(value.trim())) return EmailValidationError.invalid;
    return null;
  }
}

enum PasswordValidationError { empty, tooShort }

final class PasswordInput extends FormzInput<String, PasswordValidationError> {
  const PasswordInput.pure() : super.pure('');
  const PasswordInput.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) return PasswordValidationError.empty;
    if (value.length < 6) return PasswordValidationError.tooShort;
    return null;
  }
}
