import 'package:equatable/equatable.dart';

/// Datos del negocio que el checkout muestra (§022, solo presentación —
/// mock en CheckoutCubit; la fuente real será `GET /store/config`,
/// backend 013: dirección del local, fee de domicilio, etc.).
class CheckoutStore extends Equatable {
  const CheckoutStore({
    required this.name,
    required this.address,
    required this.deliveryFee,
  });

  final String name;

  /// Dirección del local — la línea "Lo recoges en …" del modo pickup.
  final String address;

  /// Costo fijo de domicilio en pesos — se suma al total solo en modo
  /// delivery. NO hay mínimo de domicilio (decisión del usuario §022).
  final int deliveryFee;

  @override
  List<Object?> get props => [name, address, deliveryFee];
}
