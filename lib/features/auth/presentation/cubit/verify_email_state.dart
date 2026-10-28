import 'package:equatable/equatable.dart';

import '../inputs/verify_email_inputs.dart';

enum VerifyEmailStatus { initial, inProgress, success, failure }

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
  });

  final String email;
  final CodeInput code;
  final VerifyEmailStatus status;
  final bool showCodeError;

  /// Segundos restantes antes de poder reenviar de nuevo.
  final int resendCooldown;
  final bool isResending;
  final int resendTick;

  bool get isInProgress => status == VerifyEmailStatus.inProgress;
  bool get canResend => resendCooldown == 0 && !isResending;

  VerifyEmailState copyWith({
    CodeInput? code,
    VerifyEmailStatus? status,
    bool? showCodeError,
    int? resendCooldown,
    bool? isResending,
    int? resendTick,
  }) {
    return VerifyEmailState(
      email: email,
      code: code ?? this.code,
      status: status ?? this.status,
      showCodeError: showCodeError ?? this.showCodeError,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isResending: isResending ?? this.isResending,
      resendTick: resendTick ?? this.resendTick,
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
  ];
}
