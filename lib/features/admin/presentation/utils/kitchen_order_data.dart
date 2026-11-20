import 'package:equatable/equatable.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../../orders/presentation/utils/format_phone.dart';
import '../../domain/entities/admin_order.dart';

/// Una sección de la comanda (§043 v5 — "todo por secciones y por
/// item", decisión del dueño): título ya localizado ("Se le quitó",
/// "Ingredientes", "Adicionales", "Toppings", "Salsas" — MISMO
/// vocabulario del desplegable del tile §021b) y los nombres, cada
/// uno en su línea — nada de listas inline "salsas: a, b".
class KitchenSection extends Equatable {
  const KitchenSection({required this.title, required this.names});

  final String title;
  final List<String> names;

  @override
  List<Object?> get props => [title, names];
}

/// Una línea-ítem de la comanda de cocina (§043): cantidad + nombre
/// del producto y sus `sections` ya armadas en orden — "Se le quitó"
/// primero (la excepción es lo que cocina olvida), luego
/// "Ingredientes" (la receta que SÍ lleva, snapshot includedNames),
/// Adicionales, Toppings y Salsas. Un ítem pelado solo lleva su
/// título `Nx Nombre` + la sección Ingredientes si hay snapshot.
class KitchenOrderLine extends Equatable {
  const KitchenOrderLine({
    required this.quantity,
    required this.name,
    this.sections = const [],
  });

  final int quantity;
  final String name;

  /// Secciones en orden de card — solo llegan las no-vacías.
  final List<KitchenSection> sections;

  @override
  List<Object?> get props => [quantity, name, sections];
}

/// Data ya RESUELTA de la comanda de cocina (§043): número (consecutivo
/// del POST o tag adm-N del detalle), líneas de servicio, método,
/// hora del pedido, ítems, nota y total — la card no pregunta al
/// dominio, solo compone la imagen.
///
/// SOLID (SRP): value object de presentación — ninguna pieza de la
/// card re-deriva la orden acá dentro.
class KitchenOrderData extends Equatable {
  const KitchenOrderData({
    required this.number,
    required this.serviceLines,
    required this.paymentMethod,
    required this.placedAt,
    required this.items,
    required this.total,
    this.note,
  });

  /// Número humano del pedido — el `shortTag` ('adm-N', formato
  /// aprobado §037) en AMBOS caminos: la comanda dice el MISMO
  /// identificador recién creada y reenviada desde el detalle
  /// (revisor-ui §043: '#8' en éxito vs '#adm-8' en detalle leía a
  /// cocina como dos pedidos).
  final String number;

  /// Primera = la línea de servicio junto a pago y hora ("Mesa 2" /
  /// "Para llevar" / "Domicilio"); las siguientes son el bloque de
  /// entrega del domicilio — dirección+referencia y teléfono (el
  /// dueño reparte; mismo criterio del detalle §037). Invariante:
  /// nunca vacía — la card consume `.first` en el footer sin red;
  /// las dos factories son la única vía de construcción.
  final List<String> serviceLines;

  final AdminPaymentMethod paymentMethod;

  /// Hora del pedido (placedAt), no del envío — cocina lo ordena
  /// contra el reloj real del ticket.
  final DateTime placedAt;

  final List<KitchenOrderLine> items;
  final int total;
  final String? note;

  /// Desde el BORRADOR de la comanda presencial (§043): los CartItem
  /// se mapean directo — sus CartModifier son la forma garantizada
  /// local, sin depender de cómo el POST serializó la orden. Servicio,
  /// pago, hora y total sí vienen de `order` (la verdad del servidor
  /// tras el POST); la nota se pide aparte porque el POST puede no
  /// devolverla. El número es el `shortTag` — mismo identificador
  /// que el detalle (ver `number`).
  factory KitchenOrderData.fromCartItems(
    List<CartItem> items, {
    required AdminOrder order,
    String? tableLabel,
    String? note,
    required AppLocalizations l10n,
  }) => KitchenOrderData(
    number: order.shortTag,
    serviceLines: _serviceLines(order, l10n, tableLabel: tableLabel),
    paymentMethod: order.paymentMethod,
    placedAt: order.placedAt,
    items: [
      for (final i in items)
        _line(i.productName, i.quantity, i.modifiers, i.includedNames, l10n),
    ],
    total: order.total,
    note: note,
  );

  /// Desde la orden hidratada del detalle (§043): OrderItem.modifiers
  /// ya es `List<CartModifier>` e `includedNames` viene hidratado —
  /// misma forma del borrador, el mismo reparto aplica. El número es
  /// el `shortTag` del detalle ("#adm-N", formato aprobado §037).
  factory KitchenOrderData.fromAdminOrder(
    AdminOrder order,
    AppLocalizations l10n,
  ) => KitchenOrderData(
    number: order.shortTag,
    serviceLines: _serviceLines(order, l10n),
    paymentMethod: order.paymentMethod,
    placedAt: order.placedAt,
    items: [
      for (final i in order.items)
        _line(i.name, i.quantity, i.modifiers, i.includedNames, l10n),
    ],
    total: order.total,
    note: order.note,
  );

  @override
  List<Object?> get props => [
    number,
    serviceLines,
    paymentMethod,
    placedAt,
    items,
    total,
    note,
  ];
}

/// Reparte el ítem en las secciones de la card (§043 v5) — MISMO
/// reparto del desplegable del tile (cart_item_detail_panel §021b):
/// el reemplazo gratis se comunica en "Se le quitó" como vínculo
/// "X → reemplazo" (su fila `added` no repite nombre en otra
/// sección), `added` sin grupo cae a Adicionales por convención, y
/// `includedNames` arma la sección Ingredientes (la receta que SÍ
/// lleva — cocina lee el plato completo sin memorizar la carta).
KitchenOrderLine _line(
  String name,
  int quantity,
  List<CartModifier> mods,
  List<String> included,
  AppLocalizations l10n,
) {
  final replacementNames = {
    for (final m in mods)
      if (m.action == CartModifierAction.added && m.replacesOptionId != null)
        m.replacesOptionId!: m.optionName,
  };
  final removed = [
    for (final m in mods)
      if (m.action == CartModifierAction.removed)
        replacementNames[m.optionId] == null
            ? m.optionName
            : '${m.optionName} → ${replacementNames[m.optionId]}',
  ];
  List<String> addedOf(CartModifierGroup group) => [
    for (final m in mods)
      if (m.action == CartModifierAction.added &&
          m.replacesOptionId == null &&
          (m.group ?? CartModifierGroup.extra) == group)
        // Extra repetido (§045) → "Mozzarella ×2" — solo extras
        // cobrados llegan con times > 1.
        m.times > 1 ? '${m.optionName} ×${m.times}' : m.optionName,
  ];
  final extras = addedOf(CartModifierGroup.extra);
  final toppings = addedOf(CartModifierGroup.topping);
  final sauces = addedOf(CartModifierGroup.sauce);
  return KitchenOrderLine(
    quantity: quantity,
    name: name,
    sections: [
      if (removed.isNotEmpty)
        KitchenSection(title: l10n.cartDetailRemoved, names: removed),
      if (included.isNotEmpty)
        KitchenSection(title: l10n.cartDetailIngredients, names: included),
      if (extras.isNotEmpty)
        KitchenSection(title: l10n.cartDetailExtras, names: extras),
      if (toppings.isNotEmpty)
        KitchenSection(title: l10n.cartDetailToppings, names: toppings),
      if (sauces.isNotEmpty)
        KitchenSection(title: l10n.cartDetailSauces, names: sauces),
    ],
  );
}

/// Líneas de servicio (§043): la primera arma el footer de la card
/// junto al método de pago; en domicilio la dirección+referencia va
/// en su línea y el teléfono en otra (el dueño reparte — mismo
/// criterio del detalle §037). `tableLabel` permite sobreescribir
/// la mesa con la del borrador cuando la del POST no viajó.
List<String> _serviceLines(
  AdminOrder order,
  AppLocalizations l10n, {
  String? tableLabel,
}) {
  if (order.serviceType == AdminServiceType.dineIn) {
    // La etiqueta del backend YA dice "Mesa 2" — va verbatim; sin
    // ella cae al genérico "En el local".
    final table = tableLabel ?? order.tableLabel;
    return [table ?? l10n.shareWaServiceInSite];
  }
  if (order.serviceType == AdminServiceType.pickup) {
    return [l10n.shareWaServicePickup];
  }
  final address = _addressLine(order);
  final phone = order.contactPhone;
  return [
    l10n.shareWaServiceDelivery,
    ?address,
    if (phone != null && phone.trim().isNotEmpty)
      l10n.orderContactPhone(formatPhone(phone)),
  ];
}

/// "Casa · Portón negro frente a la cancha · Barrio La Esperanza" —
/// la zona no tiene direcciones formales: etiqueta + landmark +
/// barrio se juntan en una sola línea de entrega (§037). Null cuando
/// no viajó nada.
String? _addressLine(AdminOrder order) {
  final parts = [
    order.addressLabel,
    order.landmark,
    order.neighborhood,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
