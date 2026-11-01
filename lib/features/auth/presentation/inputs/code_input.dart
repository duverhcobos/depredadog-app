import 'package:formz/formz.dart';

/// SOLID (SRP): código de 6 dígitos numéricos — compartido por
/// verify-email (verificación de correo) y forgot-password (código de
/// restablecimiento). Vivía en `verify_email_inputs.dart`; se movió a
/// archivo propio al tener un segundo consumidor (propuesta 011).
enum CodeValidationError { empty, invalid }

final class CodeInput extends FormzInput<String, CodeValidationError> {
  const CodeInput.pure([super.value = '']) : super.pure();
  const CodeInput.dirty([super.value = '']) : super.dirty();

  static final _regex = RegExp(r'^\d{6}$');

  @override
  CodeValidationError? validator(String value) {
    if (value.isEmpty) return CodeValidationError.empty;
    if (!_regex.hasMatch(value)) return CodeValidationError.invalid;
    return null;
  }
}
