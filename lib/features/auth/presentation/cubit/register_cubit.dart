import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/auth_failure.dart';
import '../../domain/use_cases/register_use_case.dart';
import '../inputs/login_inputs.dart';
import '../inputs/register_inputs.dart';
import 'register_state.dart';

/// FASE INTEGRACIÓN (propuesta 010): el submit llama a POST /auth/register
/// real. El éxito deja la cuenta `pending_verification` (sin tokens — el
/// auto-login ocurre en verify-email) y la pantalla navega a /verify-email
/// con el email tipeado. El 409 correo-duplicado devuelve al paso 2 con el
/// correo marcado (emailTaken — decisión del usuario: el error queda donde
/// se corrige).
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit({required RegisterUseCase registerUseCase})
    : _register = registerUseCase,
      super(const RegisterState());

  final RegisterUseCase _register;

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
        // Editar el correo limpia el 409 — el "ya tiene cuenta" solo
        // describe el valor anterior.
        emailTaken: false,
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
    // Opcionales: vacío → null (el datasource omite la clave en el body —
    // el backend los trata igual, pero el payload va limpio).
    final secondName = state.secondName.value.trim();
    final secondLastName = state.secondLastName.value.trim();
    final phone = state.phone.value.trim();
    final result = await _register(
      email: state.email.value,
      password: state.password.value,
      firstName: state.firstName.value.trim(),
      secondName: secondName.isEmpty ? null : secondName,
      firstLastName: state.firstLastName.value.trim(),
      secondLastName: secondLastName.isEmpty ? null : secondLastName,
      phone: phone.isEmpty ? null : phone,
    );
    if (isClosed) return;
    result.fold((failure) {
      if (failure is EmailAlreadyRegisteredFailure) {
        // 409: el error queda donde se corrige — volvemos al paso 2 con
        // el correo marcado (emailTaken → "ya tiene cuenta", prima sobre
        // el formato). El salto de paso dispara el listener de
        // currentStep (scroll reset) y el de status (toast + foco).
        emit(
          state.copyWith(
            status: RegisterStatus.authError,
            authFailure: failure,
            currentStep: 1,
            showEmailError: true,
            emailTaken: true,
          ),
        );
      } else {
        // 429/sin conexión/5xx: toast por el listener, sin moverse de
        // paso — no hay campo que señalar.
        emit(
          state.copyWith(
            status: RegisterStatus.authError,
            authFailure: failure,
          ),
        );
      }
      // Re-arma el listener (un authError consecutivo debe volver a
      // dispararlo) y limpia authFailure — emailTaken persiste: el correo
      // queda rojo hasta que el usuario lo edite.
      emit(state.copyWith(status: RegisterStatus.initial));
    }, (user) => emit(state.copyWith(status: RegisterStatus.success)));
  }
}
