import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/use_cases/resend_verification_use_case.dart';
import '../../domain/use_cases/verify_email_use_case.dart';
import '../inputs/code_input.dart';
import 'verify_email_state.dart';

/// Integración real de /auth/verify-email + /auth/resend-verification
/// (propuesta 006). El cooldown de reenvío sigue siendo Timer local.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit({
    required String email,
    required VerifyEmailUseCase verifyEmailUseCase,
    required ResendVerificationUseCase resendVerificationUseCase,
    required this._authSession,
  }) : _verifyEmail = verifyEmailUseCase,
       _resendVerification = resendVerificationUseCase,
       super(VerifyEmailState(email: email));

  final VerifyEmailUseCase _verifyEmail;
  final ResendVerificationUseCase _resendVerification;
  final AuthSession _authSession;

  Timer? _cooldownTimer;

  // status → initial al teclear: limpia authFailure (las casillas dejan de
  // pintarse en rojo en cuanto el usuario corrige) y saca al estado de
  // authError — sin esto el listener del screen no volvía a disparar el
  // toast en un error consecutivo (authError→authError mudo; revisor).
  void codeChanged(String value) => emit(
    state.copyWith(
      code: CodeInput.dirty(value),
      showCodeError: false,
      status: VerifyEmailStatus.initial,
    ),
  );

  Future<void> submit() async {
    // isResending también bloquea: un submit durante el reenvío mandaría el
    // código que esa petición acaba de invalidar en el server (carrera —
    // hallazgo del revisor).
    if (state.isInProgress || state.isResending) return;
    if (!state.code.isValid) {
      emit(
        state.copyWith(status: VerifyEmailStatus.failure, showCodeError: true),
      );
      emit(state.copyWith(status: VerifyEmailStatus.initial));
      return;
    }
    emit(state.copyWith(status: VerifyEmailStatus.inProgress));
    final result = await _verifyEmail(
      email: state.email,
      code: state.code.value,
    );
    if (isClosed) return;
    result.fold(
      // Las casillas se pintan de error vía hasError del widget
      // (InvalidCodeFailure) — el toast va por el listener del screen.
      (failure) => emit(
        state.copyWith(
          status: VerifyEmailStatus.authError,
          authFailure: failure,
        ),
      ),
      // Verificar emite sesión igual que login: tokens ya persistidos por
      // el repositorio — acá solo marcamos la sesión en memoria (guard →
      // /home) y reportamos éxito.
      (user) {
        _authSession.markAuthenticated(user);
        emit(state.copyWith(status: VerifyEmailStatus.success));
      },
    );
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    // status → initial: si veníamos de un authError (verify falló), el
    // authError posterior de ESTE resend debe ser una transición nueva —
    // si no, authError→authError no dispara el listener y el 429/red del
    // reenvío quedaba mudo para el usuario (hallazgo del revisor).
    emit(state.copyWith(isResending: true, status: VerifyEmailStatus.initial));
    final result = await _resendVerification(email: state.email);
    if (isClosed) return;
    result.fold(
      // Si el reenvío falla el código viejo sigue válido en el server —
      // NO se limpia lo tipeado (solo se limpia cuando sí se reemitió).
      (failure) => emit(
        state.copyWith(
          isResending: false,
          status: VerifyEmailStatus.authError,
          authFailure: failure,
        ),
      ),
      // Se limpia el código viejo + error: quedó invalidado por el nuevo
      // envío (revisor-ui) y el TextField queda en sync vía el listener
      // del widget.
      (_) {
        emit(
          state.copyWith(
            isResending: false,
            code: const CodeInput.pure(),
            showCodeError: false,
            resendCooldown: 60,
            resendTick: state.resendTick + 1,
          ),
        );
        _startCooldown();
      },
    );
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
