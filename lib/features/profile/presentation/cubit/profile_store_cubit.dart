import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../store/domain/entities/store_info.dart';
import 'profile_store_state.dart';

/// Datos mock del local (§030.1 — patrón §023: contrato real de
/// StoreConfigResponseDto, datos ficticios). Semana lunes→domingo en
/// el orden de pintado; domingo cerrado. En integración: GET
/// /store/config completo — la entidad `StoreInfo` ya espeja el DTO.
const kMockStoreInfo = StoreInfo(
  name: 'Depredadog',
  phone: '3007654321',
  address: 'Calle 10 #4-35, frente a la plaza',
  weeklyHours: [
    StoreDayHours(dayOfWeek: 1, opensAt: '17:00', closesAt: '23:00'),
    StoreDayHours(dayOfWeek: 2, opensAt: '17:00', closesAt: '23:00'),
    StoreDayHours(dayOfWeek: 3, opensAt: '17:00', closesAt: '23:00'),
    StoreDayHours(dayOfWeek: 4, opensAt: '17:00', closesAt: '23:00'),
    StoreDayHours(dayOfWeek: 5, opensAt: '17:00', closesAt: '23:30'),
    StoreDayHours(dayOfWeek: 6, opensAt: '17:00', closesAt: '23:30'),
    StoreDayHours(
      dayOfWeek: 0,
      opensAt: '00:00',
      closesAt: '00:00',
      isClosed: true,
    ),
  ],
);

class ProfileStoreCubit extends Cubit<ProfileStoreState> {
  ProfileStoreCubit() : super(const ProfileStoreState(store: kMockStoreInfo));
}
