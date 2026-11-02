import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';

/// `failure` = validación local (campos vacíos/formato) — patrón LoginState.
/// `authError` = error de /auth/register (propuesta 010): 409 correo ya
/// registrado, 429 throttle, sin conexión, validación de DTO, 5xx.
enum RegisterStatus { initial, inProgress, success, failure, authError }

/// Estado de `/register` (wizard de 3 pasos — propuesta 009). Los flags
/// `show*Error` se activan juntos al validar el paso/submit fallido y cada
/// uno se limpia cuando el usuario retoca SU campo — los errores aparecen
/// tras el intento de continuar, no en vivo (patrón login).
/// Los campos opcionales (segundo nombre/apellido) no tienen flag: su input
/// nunca es inválido.
class RegisterState extends Equatable {
  const RegisterState({
    this.firstName = const NameInput.pure(),
    this.secondName = const OptionalTextInput.pure(),
    this.firstLastName = const NameInput.pure(),
    this.secondLastName = const OptionalTextInput.pure(),
    this.email = const EmailInput.pure(),
    this.phone = const PhoneInput.pure(),
    this.password = const RegisterPasswordInput.pure(),
    this.confirmPassword = const ConfirmPasswordInput.pure(),
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.status = RegisterStatus.initial,
    this.currentStep = 0,
    this.showFirstNameError = false,
    this.showFirstLastNameError = false,
    this.showEmailError = false,
    this.showPhoneError = false,
    this.showPasswordError = false,
    this.showConfirmPasswordError = false,
    this.emailTaken = false,
    this.authFailure,
    this.isGoogleAuth = false,
  });

  final NameInput firstName;
  final OptionalTextInput secondName;
  final NameInput firstLastName;
  final OptionalTextInput secondLastName;
  final EmailInput email;
  final PhoneInput phone;
  final RegisterPasswordInput password;
  final ConfirmPasswordInput confirmPassword;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final RegisterStatus status;

  /// Paso actual del wizard: 0 = datos personales, 1 = cuenta, 2 = revisión.
  final int currentStep;
  final bool showFirstNameError;
  final bool showFirstLastNameError;
  final bool showEmailError;
  final bool showPhoneError;
  final bool showPasswordError;
  final bool showConfirmPasswordError;

  /// Solo true tras un 409 (EmailAlreadyRegisteredFailure): distingue el
  /// correo duplicado del error de formato en el MISMO campo — prima en
  /// [emailErrorKey] y solo se limpia al editar el correo (emailChanged).
  final bool emailTaken;

  /// Solo tiene valor cuando status == authError.
  final AuthFailure? authFailure;

  /// Solo tiene valor cuando status == success o authError: marca que la
  /// resolución vino del flujo Google (propuesta 014). En success la
  /// pantalla navega a /home (la sesión Google nace completa — sin
  /// verify-email); en authError usa el toast propio del flujo Google.
  final bool isGoogleAuth;

  bool get isValid => Formz.validate([
    firstName,
    secondName,
    firstLastName,
    secondLastName,
    email,
    phone,
    password,
    confirmPassword,
  ]);
  bool get isInProgress => status == RegisterStatus.inProgress;

  static const int lastStep = 2;
  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == lastStep;

  /// Validación por paso (propuesta 009): "Continuar" solo evalúa los campos
  /// visibles del paso — los opcionales no hace falta incluirlos (su input
  /// nunca es inválido).
  bool get isStep1Valid => Formz.validate([firstName, firstLastName, phone]);
  bool get isStep2Valid => Formz.validate([email, password, confirmPassword]);

  /// Devuelven el nombre del enum de error (`empty`/`tooShort`/`mismatch`/...)
  /// para que la UI mapee cada causa a su mensaje localizado.
  String? firstNameErrorKey() =>
      showFirstNameError && firstName.isNotValid ? firstName.error?.name : null;
  String? firstLastNameErrorKey() =>
      showFirstLastNameError && firstLastName.isNotValid
      ? firstLastName.error?.name
      : null;

  /// El 409 prima sobre el formato: el correo puede ser válido en forma
  /// y aun así estar tomado — "ya tiene cuenta" es la razón real.
  String? emailErrorKey() {
    if (emailTaken) return 'taken';
    return showEmailError && email.isNotValid ? email.error?.name : null;
  }

  String? phoneErrorKey() =>
      showPhoneError && phone.isNotValid ? phone.error?.name : null;
  String? passwordErrorKey() =>
      showPasswordError && password.isNotValid ? password.error?.name : null;
  String? confirmPasswordErrorKey() =>
      showConfirmPasswordError && confirmPassword.isNotValid
      ? confirmPassword.error?.name
      : null;

  RegisterState copyWith({
    NameInput? firstName,
    OptionalTextInput? secondName,
    NameInput? firstLastName,
    OptionalTextInput? secondLastName,
    EmailInput? email,
    PhoneInput? phone,
    RegisterPasswordInput? password,
    ConfirmPasswordInput? confirmPassword,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    RegisterStatus? status,
    int? currentStep,
    bool? showFirstNameError,
    bool? showFirstLastNameError,
    bool? showEmailError,
    bool? showPhoneError,
    bool? showPasswordError,
    bool? showConfirmPasswordError,
    bool? emailTaken,
    AuthFailure? authFailure,
    bool? isGoogleAuth,
  }) {
    return RegisterState(
      firstName: firstName ?? this.firstName,
      secondName: secondName ?? this.secondName,
      firstLastName: firstLastName ?? this.firstLastName,
      secondLastName: secondLastName ?? this.secondLastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      showFirstNameError: showFirstNameError ?? this.showFirstNameError,
      showFirstLastNameError:
          showFirstLastNameError ?? this.showFirstLastNameError,
      showEmailError: showEmailError ?? this.showEmailError,
      showPhoneError: showPhoneError ?? this.showPhoneError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      showConfirmPasswordError:
          showConfirmPasswordError ?? this.showConfirmPasswordError,
      emailTaken: emailTaken ?? this.emailTaken,
      // authFailure se limpia explícitamente pasando el nuevo status,
      // nunca se arrastra entre intentos (patrón LoginState).
      authFailure: status == RegisterStatus.authError
          ? (authFailure ?? this.authFailure)
          : null,
      // isGoogleAuth sigue la misma convención: solo describe una
      // resolución (success/authError) y se limpia al volver a
      // initial/inProgress/failure.
      isGoogleAuth:
          status == RegisterStatus.success || status == RegisterStatus.authError
          ? (isGoogleAuth ?? this.isGoogleAuth)
          : false,
    );
  }

  @override
  List<Object?> get props => [
    firstName,
    secondName,
    firstLastName,
    secondLastName,
    email,
    phone,
    password,
    confirmPassword,
    obscurePassword,
    obscureConfirmPassword,
    status,
    currentStep,
    showFirstNameError,
    showFirstLastNameError,
    showEmailError,
    showPhoneError,
    showPasswordError,
    showConfirmPasswordError,
    emailTaken,
    authFailure,
    isGoogleAuth,
  ];
}
