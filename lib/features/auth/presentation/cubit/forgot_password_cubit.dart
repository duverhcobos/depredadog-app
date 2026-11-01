import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/check_reset_code_use_case.dart';
import '../../domain/use_cases/forgot_password_use_case.dart';
import '../../domain/use_cases/reset_password_use_case.dart';
import '../inputs/code_input.dart';
import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';
import 'forgot_password_state.dart';

/// FASE INTEGRACIÓN (propuesta 012): el wizard pega a los 3 endpoints
/// reales — paso 1 envía el código (/auth/forgot-password, 200 genérico
/// anti-enumeración), paso 2 lo verifica SIN consumirlo
/// (/auth/check-reset-code) y paso 3 restablece la clave
/// (/auth/reset-password, emite IssuedSession → auto-login real — el repo
/// ya persistió los tokens, acá solo se marca la sesión en memoria).
/// El cooldown de reenvío es el mismo Timer local de verify-email y
/// arranca en 60s al entrar al paso 2 (el código acaba de salir —
/// decisión §012).
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit({
    required ForgotPasswordUseCase forgotPasswordUseCase,
    required CheckResetCodeUseCase checkResetCodeUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required this._authSession,
  }) : _forgotPassword = forgotPasswordUseCase,
       _checkResetCode = checkResetCodeUseCase,
       _resetPassword = resetPasswordUseCase,
       super(const ForgotPasswordState());

  final ForgotPasswordUseCase _forgotPassword;
  final CheckResetCodeUseCase _checkResetCode;
  final ResetPasswordUseCase _resetPassword;
  final AuthSession _authSession;

  Timer? _cooldownTimer;

  // Cada `*Changed`: dirty del input + limpia el error de ESE campo +
  // status a initial (limpia authFailure — las casillas OTP dejan de
  // pintarse en rojo en cuanto el usuario corrige — y re-arma el
  // listener; patrón verify/register).
  // El guard isInProgress cierra la vía teclado/TalkBack: IgnorePointer
  // solo tapa el puntero, y una edición durante el submit apagaría el
  // spinner antes de tiempo (revisor-ui).
  void emailChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        email: EmailInput.dirty(value.trim()),
        showEmailError: false,
        status: ForgotPasswordStatus.initial,
      ),
    );
  }

  /// isResending también bloquea (misma convención que verify): teclear
  /// durante el reenvío sería texto que el éxito de ese resend borra en
  /// unos segundos — el IgnorePointer de la UI cubre el puntero, este
  /// guard cubre teclado/TalkBack.
  void codeChanged(String value) {
    if (state.isInProgress || state.isResending) return;
    emit(
      state.copyWith(
        code: CodeInput.dirty(value),
        showCodeError: false,
        status: ForgotPasswordStatus.initial,
      ),
    );
  }

  void passwordChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        password: RegisterPasswordInput.dirty(value),
        // La confirmación compara contra la contraseña — hay que re-emitirla
        // con la referencia actualizada o el match evalúa el valor viejo
        // (una confirmación que ya coincidía debe pasar a mismatch).
        confirmPassword: state.confirmPassword.isPure
            ? ConfirmPasswordInput.pure(password: value)
            : ConfirmPasswordInput.dirty(
                password: value,
                value: state.confirmPassword.value,
              ),
        showPasswordError: false,
        status: ForgotPasswordStatus.initial,
      ),
    );
  }

  void confirmPasswordChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        confirmPassword: ConfirmPasswordInput.dirty(
          password: state.password.value,
          value: value,
        ),
        showConfirmPasswordError: false,
        status: ForgotPasswordStatus.initial,
      ),
    );
  }

  void togglePasswordVisibility() =>
      emit(state.copyWith(obscurePassword: !state.obscurePassword));

  void toggleConfirmPasswordVisibility() => emit(
    state.copyWith(obscureConfirmPassword: !state.obscureConfirmPassword),
  );

  /// Primario de los pasos 1-2: "Enviar código" pega a
  /// /auth/forgot-password y avanza al OTP con cooldown corriendo;
  /// "Verificar" pega a /auth/check-reset-code (no consume el código) y
  /// avanza a la nueva clave. Inválido local → failure con el show*Error
  /// de ESE paso → initial (re-arma el listener; la pantalla enfoca el
  /// inválido y muestra el toast). Error del backend → authError +
  /// authFailure (InvalidCodeFailure pinta las casillas en rojo vía
  /// hasError del widget; el toast va por listener). En el último paso
  /// no hace nada — su acción primaria es [submit].
  Future<void> nextStep() async {
    // isResending también bloquea: "Verificar" durante el reenvío
    // validaría el código que esa petición acaba de invalidar (carrera —
    // mismo hallazgo del revisor en verify-email).
    if (state.isInProgress || state.isResending) return;
    switch (state.currentStep) {
      case 0:
        // Re-sanitizado: el email pudo quedar sin pasar por onChanged
        // (autofill del sistema, paste) — igual que en register/submit.
        emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
        if (!state.isStep1Valid) {
          emit(
            state.copyWith(
              status: ForgotPasswordStatus.failure,
              showEmailError: true,
            ),
          );
          emit(state.copyWith(status: ForgotPasswordStatus.initial));
          return;
        }
        emit(state.copyWith(status: ForgotPasswordStatus.inProgress));
        final result = await _forgotPassword(email: state.email.value);
        if (isClosed) return;
        result.fold(
          // Se queda en paso 1 con el correo intacto: 429/sin red/5xx no
          // tienen campo que señalar — el toast va por el listener.
          (failure) => emit(
            state.copyWith(
              status: ForgotPasswordStatus.authError,
              authFailure: failure,
            ),
          ),
          // El OTP se limpia: un código pedido antes quedó invalidado por
          // este nuevo envío (cubre "cambié el correo y volví a pedir
          // código"). El cooldown arranca ya: el código acaba de salir y
          // un reenvío inmediato solo quema throttle (decisión §012).
          (_) {
            emit(
              state.copyWith(
                currentStep: 1,
                status: ForgotPasswordStatus.initial,
                code: const CodeInput.pure(),
                showCodeError: false,
                resendCooldown: 60,
              ),
            );
            _startCooldown();
          },
        );
      case 1:
        if (!state.isStep2Valid) {
          emit(
            state.copyWith(
              status: ForgotPasswordStatus.failure,
              showCodeError: true,
            ),
          );
          emit(state.copyWith(status: ForgotPasswordStatus.initial));
          return;
        }
        emit(state.copyWith(status: ForgotPasswordStatus.inProgress));
        final result = await _checkResetCode(
          email: state.email.value,
          code: state.code.value,
        );
        if (isClosed) return;
        result.fold(
          // Los dígitos se conservan: siguen vivos en el server (el check
          // no consume) — el usuario corrige o reenvía sobre lo tipeado.
          (failure) => emit(
            state.copyWith(
              status: ForgotPasswordStatus.authError,
              authFailure: failure,
            ),
          ),
          (_) => emit(
            state.copyWith(
              currentStep: 2,
              status: ForgotPasswordStatus.initial,
            ),
          ),
        );
      default:
        return; // paso 3 (nueva clave): la acción primaria es submit()
    }
  }

  /// "Atrás"/back nativo en pasos 2-3: retrocede sin re-validar — los
  /// datos ya tipeados se conservan en los inputs (clamp en 0).
  void prevStep() {
    // Guard por simetría con nextStep/submit: la pantalla ya bloquea las
    // dos vías de entrada, pero el método público se defiende igual.
    if (state.isFirstStep || state.isInProgress || state.isResending) {
      return;
    }
    emit(state.copyWith(currentStep: state.currentStep - 1));
  }

  /// "Cambiar contraseña" (paso 3): revalida TODO el wizard por si algo
  /// quedó atrás → /auth/reset-password → éxito = auto-login real (el
  /// repo ya persistió los tokens) → success → la pantalla navega a
  /// /home. InvalidCodeFailure rebota al paso 2 con el OTP en rojo: la
  /// carrera real (el check del paso 2 NO consume el código — pudo
  /// expirar o ser consumido ENTRE el check y este submit) deja el error
  /// donde se corrige (mismo patrón que el 409 de register §010).
  Future<void> submit() async {
    // isResending también bloquea (paridad defensiva con verify — hoy
    // inalcanzable porque no se puede estar en paso 3 con reenvío en
    // vuelo, pero el guard cierra la vía por simetría).
    if (state.isInProgress || state.isResending) return;
    emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
    if (!state.isValid) {
      emit(
        state.copyWith(
          status: ForgotPasswordStatus.failure,
          showEmailError: true,
          showCodeError: true,
          showPasswordError: true,
          showConfirmPasswordError: true,
        ),
      );
      emit(state.copyWith(status: ForgotPasswordStatus.initial));
      return;
    }
    emit(state.copyWith(status: ForgotPasswordStatus.inProgress));
    final result = await _resetPassword(
      email: state.email.value,
      code: state.code.value,
      newPassword: state.password.value,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        if (failure is InvalidCodeFailure) {
          // Rebota al paso 2 marcando el OTP: el código se conserva — el
          // usuario ve sus dígitos en rojo y puede corregir o reenviar
          // (el cooldown puede seguir corriendo — decisión §012).
          emit(
            state.copyWith(
              currentStep: 1,
              status: ForgotPasswordStatus.authError,
              authFailure: failure,
            ),
          );
        } else {
          // 429/sin conexión/5xx: toast por el listener, se queda en
          // paso 3 con las claves intactas — no hay campo que señalar.
          emit(
            state.copyWith(
              status: ForgotPasswordStatus.authError,
              authFailure: failure,
            ),
          );
        }
      },
      // Reset emite sesión igual que verifyEmail: tokens ya persistidos
      // por el repositorio — acá solo marcamos la sesión en memoria con
      // el usuario REAL (guard → /home) y reportamos éxito.
      (user) {
        _authSession.markAuthenticated(user);
        emit(state.copyWith(status: ForgotPasswordStatus.success));
      },
    );
  }

  /// "Reenviar" del paso 2 — el reenvío ES /auth/forgot-password otra vez
  /// (no existe variante dedicada — mismo envío). Éxito → limpia código +
  /// error + cooldown 60 + resendTick (convención verify-email; el
  /// TextField oculto queda en sync vía el listener del widget). Fallo →
  /// authError conservando los dígitos (el código viejo sigue vivo en el
  /// server).
  Future<void> resend() async {
    if (!state.canResend) return;
    // status → initial: si veníamos de un authError, el authError
    // posterior de ESTE resend debe ser una transición nueva — si no,
    // authError→authError no dispara el listener y el error quedaba mudo
    // (hallazgo del revisor en verify-email).
    emit(
      state.copyWith(isResending: true, status: ForgotPasswordStatus.initial),
    );
    final result = await _forgotPassword(email: state.email.value);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          isResending: false,
          status: ForgotPasswordStatus.authError,
          authFailure: failure,
        ),
      ),
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

  /// Timer local de cuenta regresiva — idéntico al de VerifyEmailCubit.
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
