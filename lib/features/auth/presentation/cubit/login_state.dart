import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../inputs/login_inputs.dart';

/// `failure` = validación local (campos vacíos/inválidos) — ya existía.
/// `authError` = el backend rechazó el login (credenciales, cuenta, rate
/// limit, sin conexión) — nuevo, trae `authFailure` con el motivo exacto.
enum LoginStatus { initial, inProgress, success, failure, authError }

/// Estado de la pantalla de login. `showEmailError`/`showPasswordError` se
/// activan al submit fallido y se limpian por campo al escribir de nuevo —
/// el error desaparece en cuanto el usuario corrige.
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailInput.pure(),
    this.password = const PasswordInput.pure(),
    this.obscurePassword = true,
    this.status = LoginStatus.initial,
    this.showEmailError = false,
    this.showPasswordError = false,
    this.rememberMe = false,
    this.authFailure,
    this.isGoogleAuth = false,
  });

  final EmailInput email;
  final PasswordInput password;
  final bool obscurePassword;
  final LoginStatus status;
  final bool showEmailError;
  final bool showPasswordError;

  /// Reservado a futuro (ej. recordar el correo) — la sesión siempre
  /// persiste en secure storage independientemente de este flag.
  final bool rememberMe;

  /// Solo tiene valor cuando status == authError.
  final AuthFailure? authFailure;

  /// Solo tiene valor cuando status == success o authError: marca que la
  /// resolución vino del flujo Google (propuesta 014) — la pantalla lo usa
  /// para elegir el mapeo de error de Google (toast genérico propio) en
  /// vez del de email/password.
  final bool isGoogleAuth;

  bool get isValid => Formz.validate([email, password]);
  bool get isInProgress => status == LoginStatus.inProgress;

  /// Devuelven el nombre del enum de error (`empty`/`invalid`/`tooShort`)
  /// para que la UI mapee cada causa a su mensaje localizado.
  String? emailErrorKey() =>
      showEmailError && email.isNotValid ? email.error?.name : null;
  String? passwordErrorKey() =>
      showPasswordError && password.isNotValid ? password.error?.name : null;

  LoginState copyWith({
    EmailInput? email,
    PasswordInput? password,
    bool? obscurePassword,
    LoginStatus? status,
    bool? showEmailError,
    bool? showPasswordError,
    bool? rememberMe,
    AuthFailure? authFailure,
    bool? isGoogleAuth,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      showEmailError: showEmailError ?? this.showEmailError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      rememberMe: rememberMe ?? this.rememberMe,
      // authFailure se limpia explícitamente pasando el nuevo status,
      // nunca se arrastra entre intentos (null por defecto en cada submit).
      authFailure: status == LoginStatus.authError
          ? (authFailure ?? this.authFailure)
          : null,
      // isGoogleAuth sigue la misma convención que authFailure: solo
      // describe una resolución (success/authError) y se limpia al volver
      // a initial/inProgress/failure — nunca se arrastra entre intentos.
      isGoogleAuth:
          status == LoginStatus.success || status == LoginStatus.authError
          ? (isGoogleAuth ?? this.isGoogleAuth)
          : false,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    obscurePassword,
    status,
    showEmailError,
    showPasswordError,
    rememberMe,
    authFailure,
    isGoogleAuth,
  ];
}
