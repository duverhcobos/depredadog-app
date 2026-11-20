import 'package:equatable/equatable.dart';

/// Mesa del local (GET /admin/tables — backend §019): `label` es el
/// nombre visible ("Mesa 2"), `activeOrderNumber` el consecutivo del
/// pedido dine_in vivo — null = libre. Una mesa inactiva viaja pero
/// no acepta pedidos nuevos (TABLE_NOT_FOUND del backend).
class AdminTable extends Equatable {
  const AdminTable({
    required this.id,
    required this.label,
    required this.isActive,
    required this.activeOrderNumber,
  });

  final String id;
  final String label;
  final bool isActive;

  /// Consecutivo diario del pedido vivo ocupando la mesa — null libre.
  final int? activeOrderNumber;

  /// Seleccionable para una comanda nueva: activa Y sin pedido vivo.
  bool get isFree => isActive && activeOrderNumber == null;

  @override
  List<Object?> get props => [id, label, isActive, activeOrderNumber];
}
