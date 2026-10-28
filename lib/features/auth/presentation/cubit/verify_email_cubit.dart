import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/verify_email_inputs.dart';
import 'verify_email_state.dart';

/// PROVISIONAL (fase presentación): submit y reenvío simulados — la
/// integración real de /auth/verify-email y /auth/resend-verification
/// reemplaza estos métodos en sus propios ciclos. El cooldown de reenvío
/// SÍ es real (Timer), no es parte de lo que falta integrar.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit({required String email})
    : super(VerifyEmailState(email: email));

  Timer? _cooldownTimer;

  void codeChanged(String value) =>
      emit(state.copyWith(code: CodeInput.dirty(value), showCodeError: false));

  Future<void> submit() async {
    if (state.isInProgress) return;
    if (!state.code.isValid) {
      emit(
        state.copyWith(status: VerifyEmailStatus.failure, showCodeError: true),
      );
      emit(state.copyWith(status: VerifyEmailStatus.initial));
      return;
    }
    emit(state.copyWith(status: VerifyEmailStatus.inProgress));
    // PROVISIONAL: sin endpoint todavía.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (isClosed) return;
    emit(state.copyWith(status: VerifyEmailStatus.success));
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    // Se limpia el código viejo + error: ese código quedó invalidado por el
    // nuevo envío (revisor-ui) y el TextField queda en sync vía el listener
    // del widget.
    emit(
      state.copyWith(
        code: const CodeInput.pure(),
        showCodeError: false,
        isResending: true,
      ),
    );
    // PROVISIONAL: sin endpoint todavía.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (isClosed) return;
    emit(
      state.copyWith(
        isResending: false,
        resendCooldown: 60,
        resendTick: state.resendTick + 1,
      ),
    );
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      if (state.resendCooldown <= 1) {
        emit(state.copyWith(resendCooldown: 0));
        timer.cancel();
      } else {
        emit(state.copyWith(resendCooldown: state.resendCooldown - 1));
      }
    });
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
