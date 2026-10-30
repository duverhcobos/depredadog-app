import 'package:formz/formz.dart';

/// SOLID (SRP): cada input conoce su propia regla de validación — la UI solo
/// lee `error`/`isNotValid`, nunca valida en el widget (mismo patrón que
/// login_inputs.dart). EmailInput se reusa directo de ahí.
///
/// Reglas del registro (propuesta 008):
/// - Primer nombre / primer apellido: requeridos, no-blank (trim) y solo
///   letras (con tilde/ñ), espacio o apóstrofe — nombres compuestos como
///   "María José" o "De la Cruz" pasan; el guion NO entra (decisión del
///   usuario, propuesta 009). El campo además filtra esos caracteres al
///   teclear, así que `invalid` es un respaldo defensivo.
/// - Segundo nombre / segundo apellido: opcionales, siempre válidos (el
///   filtro de input ya impide caracteres inválidos).
/// - Teléfono: opcional; con texto, celular colombiano = 10 dígitos
///   iniciando en 3 (300/310/315/350…) — decisión del usuario: solo
///   celular, solo dígitos (propuesta 009, refinamiento).
/// - Contraseña: mínimo 8 (el backend pide 8-72 — el PasswordInput del
///   login exige 6, son reglas distintas y NO se reusa).
/// - Confirmación: igual a la contraseña tipeada.
enum NameValidationError { empty, invalid }

final class NameInput extends FormzInput<String, NameValidationError> {
  const NameInput.pure() : super.pure('');
  const NameInput.dirty([super.value = '']) : super.dirty();

  /// Letras latinas (con tilde, ñ, ü), espacio y apóstrofe (recto ' y
  /// tipográfico ’ — los teclados móviles insertan el segundo). Los
  /// compuestos ("De la Cruz", "O'Neil") pasan; dígitos, @, guion y
  /// símbolos no.
  static final RegExp _allowedChars = RegExp(r"^[A-Za-záéíóúÁÉÍÓÚñÑüÜ'’ ]+$");
  static final RegExp _hasLetter = RegExp(r"[A-Za-záéíóúÁÉÍÓÚñÑüÜ]");

  @override
  NameValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return NameValidationError.empty;
    if (!_allowedChars.hasMatch(trimmed) || !_hasLetter.hasMatch(trimmed)) {
      return NameValidationError.invalid;
    }
    return null;
  }
}

/// Campos opcionales libres (segundo nombre / segundo apellido): nunca
/// producen error — `Never` como tipo de error lo deja explícito.
final class OptionalTextInput extends FormzInput<String, Never> {
  const OptionalTextInput.pure() : super.pure('');
  const OptionalTextInput.dirty([super.value = '']) : super.dirty();

  @override
  Never? validator(String value) => null;
}

enum PhoneValidationError { invalid }

final class PhoneInput extends FormzInput<String, PhoneValidationError> {
  const PhoneInput.pure() : super.pure('');
  const PhoneInput.dirty([super.value = '']) : super.dirty();

  /// Celular colombiano: 10 dígitos iniciando en 3 (3XX XXX XXXX). El
  /// campo filtra a solo dígitos, así que la regla ve números planos.
  static final RegExp _colombianMobile = RegExp(r'^3\d{9}$');

  @override
  PhoneValidationError? validator(String value) {
    if (value.trim().isEmpty) return null; // opcional
    if (!_colombianMobile.hasMatch(value)) {
      return PhoneValidationError.invalid;
    }
    return null;
  }
}

enum RegisterPasswordValidationError { empty, tooShort }

final class RegisterPasswordInput
    extends FormzInput<String, RegisterPasswordValidationError> {
  const RegisterPasswordInput.pure() : super.pure('');
  const RegisterPasswordInput.dirty([super.value = '']) : super.dirty();

  static const int minLength = 8;

  @override
  RegisterPasswordValidationError? validator(String value) {
    if (value.isEmpty) return RegisterPasswordValidationError.empty;
    if (value.length < minLength) {
      return RegisterPasswordValidationError.tooShort;
    }
    return null;
  }
}

enum ConfirmPasswordValidationError { empty, mismatch }

/// Guarda la contraseña original para comparar — el cubit la re-emite en
/// cada `passwordChanged` para que el match evalúe siempre el valor actual.
final class ConfirmPasswordInput
    extends FormzInput<String, ConfirmPasswordValidationError> {
  const ConfirmPasswordInput.pure({this.password = ''}) : super.pure('');
  const ConfirmPasswordInput.dirty({required this.password, String value = ''})
    : super.dirty(value);

  /// La contraseña contra la que se compara este campo.
  final String password;

  @override
  ConfirmPasswordValidationError? validator(String value) {
    if (value.isEmpty) return ConfirmPasswordValidationError.empty;
    if (value != password) return ConfirmPasswordValidationError.mismatch;
    return null;
  }

  // FormzInput.== solo compara value+isPure — `password` también define la
  // validez del match, así que entra en la igualdad (si no, un cambio de
  // contraseña no dispararía rebuild del campo de confirmación).
  @override
  bool operator ==(Object other) =>
      other is ConfirmPasswordInput &&
      other.value == value &&
      other.isPure == isPure &&
      other.password == password;

  @override
  int get hashCode => Object.hash(value, isPure, password);
}
