import 'package:equatable/equatable.dart';

import '../../../checkout/domain/entities/saved_address.dart';

/// Lista de direcciones guardadas (§030 presentación): mutaciones
/// optimistas locales (marcar default / eliminar) — la integración
/// hará PATCH/DELETE real con rollback al fallar.
class ProfileAddressesState extends Equatable {
  const ProfileAddressesState({required this.addresses});

  final List<SavedAddress> addresses;

  /// La predeterminada — una sola por contrato del backend.
  SavedAddress? get defaultAddress {
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return null;
  }

  ProfileAddressesState copyWith({List<SavedAddress>? addresses}) {
    return ProfileAddressesState(
      addresses: addresses ?? this.addresses,
    );
  }

  @override
  List<Object?> get props => [addresses];
}
