import '../../../cart/domain/entities/cart_item.dart';
import 'admin_order.dart';

/// Borrador de la comanda presencial (§042) — el "qué se va a
/// crear" completo antes de mandar. Los ítems son `CartItem` del
/// feature cart: su `CartModifier` serializa 1:1 a
/// `items[].modifiers` del POST /admin/orders (mismo shape
/// `optionId`+`action`+`replacesOptionId` — no se traduce nada).
/// El teléfono solo tiene sentido en transfer (el contrato lo
/// exige ahí y lo prohíbe en cash); la mesa solo en dineIn.
class AdminNewOrderDraft {
  const AdminNewOrderDraft({
    required this.serviceType,
    required this.paymentMethod,
    required this.items,
    this.tableId,
    this.payerPhone,
    this.notes,
  });

  /// dineIn (mesa) | pickup (mostrador/para llevar) — delivery
  /// presencial no existe en el contrato.
  final AdminServiceType serviceType;
  final String? tableId;

  /// Efectivo | Transf. — presencial no admite Nequi gateway.
  final AdminPaymentMethod paymentMethod;
  final String? payerPhone;

  final List<CartItem> items;
  final String? notes;

  int get total => items.fold(0, (s, i) => s + i.lineTotal);
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
}
