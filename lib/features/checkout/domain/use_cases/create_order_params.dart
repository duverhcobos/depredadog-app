/// Comando de POST /orders (§026 — backend 015). Los ~10 campos del
/// payload en un objeto valor: la firma de repo/use-case queda en un
/// parámetro. Dominio puro — la serialización JSON vive en data/
/// (el repo impl arma el Map, igual que saveAddress).
class CreateOrderParams {
  const CreateOrderParams({
    required this.serviceType,
    required this.paymentMethod,
    required this.items,
    required this.clientRequestId,
    this.addressId,
    this.newLandmark,
    this.newNeighborhood,
    this.contactPhone,
    this.deliveryLocationLink,
    this.payerPhone,
    this.notes,
  });

  /// 'pickup' | 'delivery' — el enum del backend.
  final String serviceType;

  /// 'cash' | 'transfer' — el Nequi de la UI viaja como 'transfer'.
  final String paymentMethod;

  final List<OrderItemInput> items;

  /// Idempotencia (§015): un uuid por instancia de checkout; un
  /// reintento responde la orden ya creada en vez de duplicarla.
  final String clientRequestId;

  /// Domicilio con dirección guardada — la seleccionada o la recién
  /// persistida por "Guardar esta ubicación" (justSavedAddress).
  final String? addressId;

  /// Domicilio con "Nueva ubicación" no guardada — landmark exigido,
  /// neighborhood opcional (XOR con addressId).
  final String? newLandmark;
  final String? newNeighborhood;

  /// §024 — celular de quién recibe (delivery lo exige).
  final String? contactPhone;

  /// Pin de Google Maps adjunto al pedido (§022d — hoy el link mock;
  /// viaja para que el pipe quede probado hasta la geo real).
  final String? deliveryLocationLink;

  /// §024 — celular que paga cuando transfer (Nequi).
  final String? payerPhone;

  final String? notes;
}

/// Ítem del pedido — espejo de OrderItemDto del backend (sin notes:
/// el carrito no tiene nota por ítem).
class OrderItemInput {
  const OrderItemInput({
    required this.productId,
    required this.quantity,
    this.modifiers = const [],
  });

  final String productId;
  final int quantity;
  final List<OrderModifierInput> modifiers;
}

/// Modificador del ítem — espejo de OrderItemModifierDto del backend.
class OrderModifierInput {
  const OrderModifierInput({
    required this.optionId,
    required this.action,
    this.replacesOptionId,
  });

  final String optionId;

  /// 'added' | 'removed' — el enum del backend.
  final String action;

  /// Solo en `added` de un reemplazo gratis (§021): apunta al
  /// ingrediente incluido agotado que esta opción reemplaza.
  final String? replacesOptionId;
}
