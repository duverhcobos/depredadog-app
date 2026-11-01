import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../inputs/code_input.dart';
import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';

/// `failure` = validación local (campos vacíos/formato) — patrón
/// RegisterState. SIN `authError`: la fase presentación no pega al
/// backend; la integración (forgot-password / check-reset-code /
/// reset-password) lo agregará junto a `authFailure`.
enum ForgotPasswordStatus { initial, inProgress, success, failure }

/// Estado de `/forgot-password` (wizard de 3 pasos — propuesta 011):
/// correo → código OTP → nueva contraseña. Los flags `show*Error` se
/// activan juntos al validar el paso/submit fallido y cada uno se limpia
/// cuando el usuario retoca SU campo — los errores aparecen tras el
/// intento de continuar, no en vivo (patrón register).
/// `resendCooldown`/`isResending`/`resendTick` espejan el cooldown de
/// verify-email (Timer local de 60s simulado; `resendTick` dispara el
/// toast de éxito desde un BlocListener propio).
class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.email = const EmailInput.pure(),
    this.code = const CodeInput.pure(),
    this.password = const RegisterPasswordInput.pure(),
    this.confirmPassword = const ConfirmPasswordInput.pure(),
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.status = ForgotPasswordStatus.initial,
    this.currentStep = 0,
    this.showEmailError = false,
    this.showCodeError = false,
    this.showPasswordError = false,
    this.showConfirmPasswordError = false,
    this.resendCooldown = 0,
    this.isResending = false,
    this.resendTick = 0,
  });

  final EmailInput email;
  final CodeInput code;
  final RegisterPasswordInput password;
  final ConfirmPasswordInput confirmPassword;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final ForgotPasswordStatus status;

  /// Paso actual del wizard: 0 = correo, 1 = código OTP, 2 = nueva clave.
  final int currentStep;
  final bool showEmailError;
  final bool showCodeError;
  final bool showPasswordError;
  final bool showConfirmPasswordError;

  /// Segundos restantes antes de poder reenviar de nuevo (paso 2).
  final int resendCooldown;
  final bool isResending;
  final int resendTick;

  bool get isValid => Formz.validate([email, code, password, confirmPassword]);
  bool get isInProgress => status == ForgotPasswordStatus.inProgress;

  static const int lastStep = 2;
  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == lastStep;

  /// Validación por paso: "Enviar código"/"Verificar" solo evalúan los
  /// campos visibles del paso.
  bool get isStep1Valid => Formz.validate([email]);
  bool get isStep2Valid => Formz.validate([code]);
  bool get isStep3Valid => Formz.validate([password, confirmPassword]);

  // !isInProgress: un resend durante el submit invalidaría el código que
  // la petición tiene en vuelo (misma carrera que verify-email).
  bool get canResend => resendCooldown == 0 && !isResending && !isInProgress;

  /// Devuelven el nombre del enum de error (`empty`/`invalid`/`tooShort`/
  /// `mismatch`) para que la UI mapee cada causa a su mensaje localizado.
  String? emailErrorKey() =>
      showEmailError && email.isNotValid ? email.error?.name : null;
  String? codeErrorKey() =>
      showCodeError && code.isNotValid ? code.error?.name : null;
  String? passwordErrorKey() =>
      showPasswordError && password.isNotValid ? password.error?.name : null;
  String? confirmPasswordErrorKey() =>
      showConfirmPasswordError && confirmPassword.isNotValid
      ? confirmPassword.error?.name
      : null;

  ForgotPasswordState copyWith({
    EmailInput? email,
    CodeInput? code,
    RegisterPasswordInput? password,
    ConfirmPasswordInput? confirmPassword,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    ForgotPasswordStatus? status,
    int? currentStep,
    bool? showEmailError,
    bool? showCodeError,
    bool? showPasswordError,
    bool? showConfirmPasswordError,
    int? resendCooldown,
    bool? isResending,
    int? resendTick,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      code: code ?? this.code,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      showEmailError: showEmailError ?? this.showEmailError,
      showCodeError: showCodeError ?? this.showCodeError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      showConfirmPasswordError:
          showConfirmPasswordError ?? this.showConfirmPasswordError,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isResending: isResending ?? this.isResending,
      resendTick: resendTick ?? this.resendTick,
    );
  }

  @override
  List<Object?> get props => [
    email,
    code,
    password,
    confirmPassword,
    obscurePassword,
    obscureConfirmPassword,
    status,
    currentStep,
    showEmailError,
    showCodeError,
    showPasswordError,
    showConfirmPasswordError,
    resendCooldown,
    isResending,
    resendTick,
  ];
}
