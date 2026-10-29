import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/use_cases/restore_session_use_case.dart';
import 'splash_state.dart';

/// Orquesta la restauración de sesión al abrir la app — la única lógica
/// de la splash screen (bloc-patterns: la pantalla queda dumb). Éxito →
/// marca AuthSession (igual que login/verify); fracaso → guest, la
/// pantalla navega a /login sin más detalle.
class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required RestoreSessionUseCase restoreSessionUseCase,
    required this._authSession,
  }) : _restoreSession = restoreSessionUseCase,
       super(const SplashState());

  final RestoreSessionUseCase _restoreSession;
  final AuthSession _authSession;

  /// Devuelve el Future para que la pantalla lo espere EN PARALELO con su
  /// delay de marca — la navegación sale en max(800ms, restore).
  Future<void> restoreSession() async {
    final result = await _restoreSession();
    if (isClosed) return;
    result.fold((_) => emit(const SplashState(status: SplashStatus.guest)), (
      user,
    ) {
      _authSession.markAuthenticated(user);
      emit(const SplashState(status: SplashStatus.restored));
    });
  }
}
