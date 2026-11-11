import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../checkout/domain/entities/saved_address.dart';
import 'profile_addresses_state.dart';

/// Mocks de direcciones (§030) — tres filas: default casa, trabajo,
/// otra. En integración: GET /addresses (default-primero lo ordena el
/// backend), POST crear, PATCH :id (editar / {isDefault:true}), DELETE.
const kMockAddresses = <SavedAddress>[
  SavedAddress(
    id: 'a1',
    label: 'Casa',
    landmark: 'Casa blanca reja negra',
    neighborhood: 'Barrio Centro',
    type: SavedAddressType.home,
    isDefault: true,
  ),
  SavedAddress(
    id: 'a2',
    label: 'Trabajo',
    landmark: 'Oficina 201, edificio azul',
    neighborhood: 'Pueblo Nuevo',
    type: SavedAddressType.work,
  ),
  SavedAddress(
    id: 'a3',
    label: 'Mamá',
    landmark: 'Frente al parque',
    type: SavedAddressType.other,
  ),
];

class ProfileAddressesCubit extends Cubit<ProfileAddressesState> {
  ProfileAddressesCubit()
    : super(const ProfileAddressesState(addresses: kMockAddresses));

  /// Fase 1: mutación optimista local — exclusividad de default como
  /// la hace el backend (una sola predeterminada).
  void markDefault(String id) {
    emit(
      state.copyWith(
        addresses: [
          for (final a in state.addresses) a.copyWith(isDefault: a.id == id),
        ],
      ),
    );
  }

  /// Fase 1: borrado local — si la eliminada era la default, la
  /// primera restante la hereda (invariante "una sola default" que
  /// el backend garantizará; fase 1 lo simula el mock). En
  /// integración: DELETE con rollback si el servidor rechaza +
  /// re-fetch honesto.
  void delete(String id) {
    final remaining = [
      for (final a in state.addresses)
        if (a.id != id) a,
    ];
    if (remaining.isNotEmpty && !remaining.any((a) => a.isDefault)) {
      remaining[0] = remaining[0].copyWith(isDefault: true);
    }
    emit(state.copyWith(addresses: remaining));
  }

  /// Fase 1: upsert del form (crear → id mock, editar → reemplaza).
  /// En integración: POST para nueva (el backend la asigna default si
  /// es la primera) / PATCH :id para editar — ambos con la lista
  /// reordenada default-primero que devuelve el backend.
  void upsert(SavedAddress address) {
    final existing = state.addresses.any((a) => a.id == address.id);
    emit(
      state.copyWith(
        addresses: [
          for (final a in state.addresses)
            if (a.id == address.id) address else a,
          if (!existing) address,
        ],
      ),
    );
  }
}
