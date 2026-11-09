import 'package:equatable/equatable.dart';

/// Orden creada por POST /orders (§026 — backend 015). El diálogo de
/// éxito NO muestra el consecutivo (§022b — no revelar el volumen del
/// negocio); `id`/`orderNumber` quedan para el detalle real del ciclo 3.
class PlacedOrder extends Equatable {
  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
  });

  final String id;

  /// Consecutivo diario `#N` (visible solo para el local hoy).
  final int orderNumber;

  /// 'pending' al nacer.
  final String status;

  /// Total cobrado ya validado server-side (snapshot de la orden).
  final int total;

  @override
  List<Object?> get props => [id, orderNumber, status, total];
}
