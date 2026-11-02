import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/use_cases/google_sign_in_use_case.dart';
import '../../domain/use_cases/login_use_case.dart';
import '../inputs/login_inputs.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required this._loginUseCase,
    required this._googleSignInUseCase,
    required this._authSession,
  }) : super(const LoginState());

  final LoginUseCase _loginUseCase;
  final GoogleSignInUseCase _googleSignInUseCase;
  final AuthSession _authSession;

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
    final result = await _loginUseCase(
      email: state.email.value,
      password: state.password.value,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(
          state.copyWith(status: LoginStatus.authError, authFailure: failure),
        );
        emit(state.copyWith(status: LoginStatus.initial));
      },
      (user) {
        _authSession.markAuthenticated(user);
        emit(state.copyWith(status: LoginStatus.success));
      },
    );
  }

  /// Flujo Google (propuesta 014): cancel = vuelve a initial en silencio;
  /// éxito = sesión persistida → markAuthenticated → success → el listener
  /// navega a /home; error = authError marcado isGoogleAuth para que la
  /// pantalla use el toast propio del flujo Google.
  Future<void> signInWithGoogle() async {
    if (state.isInProgress) return;
    emit(state.copyWith(status: LoginStatus.inProgress));
    final result = await _googleSignInUseCase();
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: LoginStatus.authError,
            authFailure: failure,
            isGoogleAuth: true,
          ),
        );
        emit(state.copyWith(status: LoginStatus.initial));
      },
      (user) {
        if (user == null) {
          emit(state.copyWith(status: LoginStatus.initial));
          return;
        }
        _authSession.markAuthenticated(user);
        emit(state.copyWith(status: LoginStatus.success, isGoogleAuth: true));
      },
    );
  }
}
