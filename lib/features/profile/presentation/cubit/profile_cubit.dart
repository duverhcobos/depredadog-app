import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user.dart';
import 'profile_state.dart';

/// Datos mock del tab Perfil (§030/§030.1 — patrón §023: contrato
/// real, datos ficticios). En integración: `load()` = GET /auth/me +
/// conteo de direcciones; `updateUser()` = PATCH /auth/me; `logout()`
/// = POST /auth/logout + limpieza local.
const kMockProfileUser = User(
  id: 'mock-u1',
  email: 'ana@test.com',
  firstName: 'Ana',
  firstLastName: 'López',
  phone: '3001234567',
  role: 'customer',
  status: 'active',
);

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit()
    : super(
        const ProfileState(
          user: kMockProfileUser,
          referralCode: 'XK2P9QRD',
          loyaltyPoints: 120,
          referredCount: 2,
        ),
      );

  /// §030.1 — mutación local del form "Mis datos" (fase 1: solo el
  /// state — el PATCH /auth/me real es pendiente del backend). La
  /// pantalla arma el User nuevo (la entidad no tiene copyWith: se
  /// reconstruye conservando id/email/role/status).
  void updateUser(User user) => emit(state.copyWith(user: user));

  /// Fase 1: la acción real (POST /auth/logout + limpieza) es del
  /// ciclo de integración — el diálogo ya es real, esto solo marca.
  Future<void> logout() async {}
}
