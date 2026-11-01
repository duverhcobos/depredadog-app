import 'package:equatable/equatable.dart';

import '../../domain/failures/auth_failure.dart';
import '../inputs/code_input.dart';

/// `failure` = validación local (código vacío/formato) — ya existía.
/// `authError` = el backend rechazó verify o resend (código inválido, rate
/// limit, sin conexión) — trae `authFailure` con el motivo (mismo patrón
/// que LoginState §004).
enum VerifyEmailStatus { initial, inProgress, success, failure, authError }

/// `resendTick` incrementa en cada reenvío completado — BlocListener lo usa
/// para disparar el toast de éxito sin boolean "de un solo uso" propenso a
/// condiciones de carrera.
class VerifyEmailState extends Equatable {
  const VerifyEmailState({
    required this.email,
    this.code = const CodeInput.pure(),
    this.status = VerifyEmailStatus.initial,
    this.showCodeError = false,
    this.resendCooldown = 0,
    this.isResending = false,
    this.resendTick = 0,
    this.authFailure,
  });

  final String email;
  final CodeInput code;
  final VerifyEmailStatus status;
  final bool showCodeError;

  /// Segundos restantes antes de poder reenviar de nuevo.
  final int resendCooldown;
  final bool isResending;
  final int resendTick;

  /// Solo tiene valor cuando status == authError.
  final AuthFailure? authFailure;

  bool get isInProgress => status == VerifyEmailStatus.inProgress;
  // !isInProgress: un resend durante la verificación invalidaría el código
  // que el submit tiene en vuelo (misma carrera que submit-durante-resend).
  bool get canResend => resendCooldown == 0 && !isResending && !isInProgress;

  VerifyEmailState copyWith({
    CodeInput? code,
    VerifyEmailStatus? status,
    bool? showCodeError,
    int? resendCooldown,
    bool? isResending,
    int? resendTick,
    AuthFailure? authFailure,
  }) {
    return VerifyEmailState(
      email: email,
      code: code ?? this.code,
      status: status ?? this.status,
      showCodeError: showCodeError ?? this.showCodeError,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isResending: isResending ?? this.isResending,
      resendTick: resendTick ?? this.resendTick,
      authFailure: status == VerifyEmailStatus.authError
          ? (authFailure ?? this.authFailure)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    email,
    code,
    status,
    showCodeError,
    resendCooldown,
    isResending,
    resendTick,
    authFailure,
  ];
}
