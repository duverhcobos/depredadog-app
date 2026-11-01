import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/entities/user.dart';
import '../inputs/code_input.dart';
import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';
import 'forgot_password_state.dart';

/// FASE PRESENTACIÓN (propuesta 011): los submits son SIMULADOS — el
/// "envío" del código, el "check" del OTP y el reset de la contraseña son
/// solo validación local + avance de paso; el submit final espera
/// [simulatedDelay], marca una sesión stub en [AuthSession] (sin ella el
/// guard rebota /home → /login en silencio — el destino real del flujo
/// es auto-login, así que la simulación debe ser fiel) y emite éxito.
/// La sesión fake solo vive en RAM: muere al reiniciar la app.
/// La integración de forgot-password / check-reset-code / reset-password
/// llega en su propia propuesta: ahí el cubit recibirá los use cases por
/// DI como RegisterCubit en §010.
/// El cooldown de reenvío es el mismo Timer local de verify-email.
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit({
    required this._authSession,
    this.simulatedDelay = const Duration(milliseconds: 800),
  }) : super(const ForgotPasswordState());

  final AuthSession _authSession;

  /// Delay del submit/reenvío simulado — inyectable para que los tests
  /// no esperen.
  final Duration simulatedDelay;

  Timer? _cooldownTimer;

  // Cada `*Changed`: dirty del input + limpia el error de ESE campo +
  // status a initial (re-arma el listener — patrón register/verify).
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

  /// Primario de los pasos 1-2 ("Enviar código" / "Verificar"): valida
  /// SOLO los campos del paso actual. Inválido → failure con el show*Error
  /// de ESE paso → initial (re-arma el listener; la pantalla enfoca el
  /// inválido y muestra el toast). Válido → avanza un paso — el envío y
  /// el check del código son simulados, no hay petición que esperar.
  /// En el último paso no hace nada — su acción primaria es [submit].
  void nextStep() {
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
        emit(
          state.copyWith(currentStep: 1, status: ForgotPasswordStatus.initial),
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
        emit(
          state.copyWith(currentStep: 2, status: ForgotPasswordStatus.initial),
        );
      default:
        return; // paso 3 (nueva clave): la acción primaria es submit()
    }
  }

  /// "Atrás"/back nativo en pasos 2-3: retrocede sin re-validar — los
  /// datos ya tipeados se conservan en los inputs (clamp en 0).
  void prevStep() {
    if (state.isFirstStep) return;
    emit(state.copyWith(currentStep: state.currentStep - 1));
  }

  /// "Cambiar contraseña" (paso 3): revalida TODO el wizard por si algo
  /// quedó atrás → delay simulado → success → la pantalla navega a /home
  /// (en el flujo real el reset devuelve tokens y el auto-login entra a
  /// /home — mismo destino).
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
    // SIMULADO: el endpoint real (200 genérico anti-enumeración, 400,
    // 429, código inválido→rebote al paso 2) llega con la integración —
    // por ahora toda clave válida "cambia" la contraseña tras el delay.
    await Future<void>.delayed(simulatedDelay);
    if (isClosed) return;
    // Sesión stub: sin ella el guard rebota /home → /login en silencio
    // y el "éxito" se veía como abandono (hallazgo CRÍTICO revisor-ui).
    // Solo vive en RAM — la próxima cold start restoreSession falla y
    // vuelve a /login (no hay tokens reales en storage).
    _authSession.markAuthenticated(
      User(
        id: 'forgot-preview',
        email: state.email.value,
        firstName: 'Recuperación',
        firstLastName: 'Preview',
        role: 'customer',
        status: 'active',
      ),
    );
    emit(state.copyWith(status: ForgotPasswordStatus.success));
  }

  /// "Reenviar" del paso 2 — envío simulado: isResending → delay →
  /// cooldown 60s. Se limpia el código viejo + su error: quedó invalidado
  /// por el nuevo envío (convención verify-email) y el TextField oculto
  /// queda en sync vía el listener del widget.
  Future<void> resend() async {
    if (!state.canResend) return;
    emit(
      state.copyWith(isResending: true, status: ForgotPasswordStatus.initial),
    );
    await Future<void>.delayed(simulatedDelay);
    if (isClosed) return;
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
