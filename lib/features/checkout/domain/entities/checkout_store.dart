import 'package:equatable/equatable.dart';

/// Datos del negocio que el checkout muestra (fuente real:
/// `GET /store/config`, backend 013 — nombre, dirección del local, fee
/// de domicilio, apertura).
class CheckoutStore extends Equatable {
  const CheckoutStore({
    required this.name,
    required this.address,
    required this.deliveryFee,
    this.isOpen = true,
    this.minDeliveryOrder,
    this.logoUrl,
  });

  final String name;

  /// Dirección del local — la línea "Lo recoges en …" del modo pickup.
  final String address;

  /// Costo fijo de domicilio en pesos — se suma al total solo en modo
  /// delivery (si el backend lo deja en 0 la UI dice "Gratis", §022a).
  final int deliveryFee;

  /// Derivado del horario del negocio (backend 013) — si false el
  /// checkout bloquea el confirm (el backend rechaza con 409).
  final bool isOpen;

  /// Mínimo de domicilio en COP; null = sin mínimo (decisión §022).
  final int? minDeliveryOrder;

  final String? logoUrl;

  @override
  List<Object?> get props => [
    name,
    address,
    deliveryFee,
    isOpen,
    minDeliveryOrder,
    logoUrl,
  ];
}
