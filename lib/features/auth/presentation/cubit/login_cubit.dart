import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/login_inputs.dart';
import 'login_state.dart';

/// PROVISIONAL (fase presentación): el submit simula la llamada al backend
/// con un delay y emite `success` — la integración real de /auth/login
/// reemplaza este método en la propuesta de integración.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  /// Al escribir se limpia el error de ESE campo — la alerta desaparece
  /// en cuanto el usuario empieza a corregir.
  void emailChanged(String value) => emit(
    state.copyWith(
      email: EmailInput.dirty(value.trim()),
      showEmailError: false,
    ),
  );

  void passwordChanged(String value) => emit(
    state.copyWith(
      password: PasswordInput.dirty(value),
      showPasswordError: false,
    ),
  );

  void togglePasswordVisibility() =>
      emit(state.copyWith(obscurePassword: !state.obscurePassword));

  void rememberMeChanged(bool value) => emit(state.copyWith(rememberMe: value));

  /// Re-sanitiza el email por si algo quedó sin pasar por `onChanged`
  /// (paste largo, autofill del sistema) antes de validar.
  Future<void> submit() async {
    if (state.isInProgress) return; // doble tap / tap + done del teclado
    emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
    if (!state.isValid) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          showEmailError: true,
          showPasswordError: true,
        ),
      );
      emit(state.copyWith(status: LoginStatus.initial));
      return;
    }
    emit(state.copyWith(status: LoginStatus.inProgress));
    // PROVISIONAL: sin endpoint todavía — delay para mostrar el loading.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (isClosed) return;
    emit(state.copyWith(status: LoginStatus.success));
  }
}
