import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';
import 'register_state.dart';

/// FASE PRESENTACIÓN (propuesta 009): el submit es SIMULADO — delay ~800ms
/// y éxito directo; la pantalla navega a /verify-email con el email tipeado
/// (el flujo real cierra solo porque esa pantalla ya está integrada).
/// La integración de POST /auth/register llega en su propia propuesta:
/// ahí el cubit recibirá el use case por DI como LoginCubit/VerifyEmailCubit.
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit({this.simulatedDelay = const Duration(milliseconds: 800)})
    : super(const RegisterState());

  /// Delay del submit simulado — inyectable para que los tests no esperen.
  final Duration simulatedDelay;

  // Cada `*Changed`: dirty del input + limpia el error de ESE campo +
  // status a initial (limpia authFailure y re-arma el listener — patrón
  // verify §006). Los campos opcionales no tienen flag que limpiar.
  // El guard isInProgress cierra la vía teclado/TalkBack: IgnorePointer
  // solo tapa el puntero, y una edición durante el submit apagaría el
  // spinner antes de tiempo (revisor-ui).
  void firstNameChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        firstName: NameInput.dirty(value),
        showFirstNameError: false,
        status: RegisterStatus.initial,
      ),
    );
  }

  void secondNameChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        secondName: OptionalTextInput.dirty(value),
        status: RegisterStatus.initial,
      ),
    );
  }

  void firstLastNameChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        firstLastName: NameInput.dirty(value),
        showFirstLastNameError: false,
        status: RegisterStatus.initial,
      ),
    );
  }

  void secondLastNameChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        secondLastName: OptionalTextInput.dirty(value),
        status: RegisterStatus.initial,
      ),
    );
  }

  void emailChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        email: EmailInput.dirty(value.trim()),
        showEmailError: false,
        status: RegisterStatus.initial,
      ),
    );
  }

  void phoneChanged(String value) {
    if (state.isInProgress) return;
    emit(
      state.copyWith(
        phone: PhoneInput.dirty(value),
        showPhoneError: false,
        status: RegisterStatus.initial,
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
        status: RegisterStatus.initial,
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
        status: RegisterStatus.initial,
      ),
    );
  }

  void togglePasswordVisibility() =>
      emit(state.copyWith(obscurePassword: !state.obscurePassword));

  void toggleConfirmPasswordVisibility() => emit(
    state.copyWith(obscureConfirmPassword: !state.obscureConfirmPassword),
  );

  /// "Continuar" del wizard (propuesta 009): valida SOLO los campos del
  /// paso actual. Inválido → failure con los show*Error de ESE paso →
  /// initial (re-arma el listener; la pantalla enfoca el primer inválido
  /// del paso y muestra el toast). Válido → avanza un paso. En el último
  /// paso (revisión) no hace nada — su acción primaria es [submit].
  void nextStep() {
    if (state.isInProgress) return; // doble tap
    switch (state.currentStep) {
      case 0:
        if (!state.isStep1Valid) {
          emit(
            state.copyWith(
              status: RegisterStatus.failure,
              showFirstNameError: true,
              showFirstLastNameError: true,
              showPhoneError: true,
            ),
          );
          emit(state.copyWith(status: RegisterStatus.initial));
          return;
        }
        emit(state.copyWith(currentStep: 1, status: RegisterStatus.initial));
      case 1:
        // Mismo re-sanitizado que submit: el email pudo quedar sin pasar
        // por onChanged (autofill del sistema, paste).
        emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
        if (!state.isStep2Valid) {
          emit(
            state.copyWith(
              status: RegisterStatus.failure,
              showEmailError: true,
              showPasswordError: true,
              showConfirmPasswordError: true,
            ),
          );
          emit(state.copyWith(status: RegisterStatus.initial));
          return;
        }
        emit(state.copyWith(currentStep: 2, status: RegisterStatus.initial));
      default:
        return; // paso 2 (revisión): la acción primaria es submit()
    }
  }

  /// Flecha back en pasos 2-3: retrocede sin re-validar — los datos ya
  /// tipeados se conservan en los inputs (clamp en 0 por seguridad).
  void prevStep() {
    if (state.isFirstStep) return;
    emit(state.copyWith(currentStep: state.currentStep - 1));
  }

  /// Re-sanitiza el email por si algo quedó sin pasar por `onChanged`
  /// (paste largo, autofill del sistema) antes de validar.
  Future<void> submit() async {
    if (state.isInProgress) return; // doble tap / tap + done del teclado
    emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
    if (!state.isValid) {
      emit(
        state.copyWith(
          status: RegisterStatus.failure,
          showFirstNameError: true,
          showFirstLastNameError: true,
          showEmailError: true,
          showPhoneError: true,
          showPasswordError: true,
          showConfirmPasswordError: true,
        ),
      );
      emit(state.copyWith(status: RegisterStatus.initial));
      return;
    }
    emit(state.copyWith(status: RegisterStatus.inProgress));
    // SIMULADO: el endpoint real (409/400/429) llega con la integración —
    // por ahora todo registro válido "crea" la cuenta tras el delay.
    await Future<void>.delayed(simulatedDelay);
    if (isClosed) return;
    emit(state.copyWith(status: RegisterStatus.success));
  }
}
