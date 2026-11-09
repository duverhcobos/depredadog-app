import '../../domain/entities/placed_order.dart';

/// Parser del OrderResponseDto (§015). Solo toma los campos de la
/// entidad — el response trae ítems/pago/dirección completos pero el
/// checkout no los consume (el detalle real del ciclo 3 hace GET
/// /orders/:id propio).
class PlacedOrderModel extends PlacedOrder {
  const PlacedOrderModel({
    required super.id,
    required super.orderNumber,
    required super.status,
    required super.total,
  });

  factory PlacedOrderModel.fromJson(Map<String, dynamic> json) =>
      PlacedOrderModel(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as int,
        status: json['status'] as String,
        total: json['total'] as int,
      );
}
