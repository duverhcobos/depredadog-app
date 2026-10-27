import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../inputs/login_inputs.dart';

enum LoginStatus { initial, inProgress, success, failure }

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
  });

  final EmailInput email;
  final PasswordInput password;
  final bool obscurePassword;
  final LoginStatus status;
  final bool showEmailError;
  final bool showPasswordError;

  /// En la integración decidirá si el refresh token se persiste entre
  /// sesiones (secure storage) o la sesión muere al cerrar la app.
  final bool rememberMe;

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
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      showEmailError: showEmailError ?? this.showEmailError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      rememberMe: rememberMe ?? this.rememberMe,
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
  ];
}
