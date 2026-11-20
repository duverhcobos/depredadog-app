import 'package:equatable/equatable.dart';

import '../../../cart/domain/entities/cart_item.dart';
import '../../../home/domain/entities/catalog_category.dart';
import '../../../home/domain/entities/catalog_product.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/entities/admin_table.dart';
import '../../domain/failures/admin_failure.dart';

/// Estado de la comanda (§042): la carta + mesas cargadas una vez,
/// el borrador en construcción, y el paso interno
/// (comanda→cobro) en vez de ruta hermana.
enum AdminNewOrderStep { comanda, cobro }

/// Resultado del submit (§042) — record ligero como AdminHistoryPage:
/// la pantalla tosteea por `failure.errorCode` o celebra con
/// `order.orderNumber` + pop.
typedef AdminNewOrderSubmit = ({AdminOrder? order, AdminFailure? failure});

/// Estado del borrador de la comanda presencial (§042).
class AdminNewOrderState extends Equatable {
  const AdminNewOrderState({
    this.categories = const [],
    this.tables = const [],
    this.loading = true,
    this.failed = false,
    this.items = const [],
    this.step = AdminNewOrderStep.comanda,
    this.serviceType = AdminServiceType.dineIn,
    this.selectedTableId,
    this.selectedCategorySlug,
    this.paymentMethod = AdminPaymentMethod.cash,
    this.payerPhone = '',
    this.notes = '',
    this.submitting = false,
  });

  /// Carta real del GET /catalog — fila por fila igual que la ve el
  /// cliente (isSellable/respeto de agotados incluido).
  final List<CatalogCategory> categories;

  /// Mesas con ocupación (GET /admin/tables) — re-sincronizan tras
  /// un TABLE_NOT_FOUND del submit.
  final List<AdminTable> tables;

  /// Carga inicial de carta+mesas en vuelo.
  final bool loading;

  /// El load falló sin datos — vista de error completa con
  /// Reintentar (misma convención de la cola §038).
  final bool failed;

  /// Ítems del borrador — CartItem del feature cart: su
  /// CartModifier serializa 1:1 al POST (§042).
  final List<CartItem> items;

  /// Paso interno — una sola ruta /admin/orders/new (§042).
  final AdminNewOrderStep step;

  /// dineIn (mesa) | pickup (para llevar) — default dineIn.
  final AdminServiceType serviceType;

  /// Mesa elegida en dineIn — null sin elegir; se limpia al pasar a
  /// pickup (tableId prohibido ahí).
  final String? selectedTableId;

  /// Filtro de la comanda — null = "Todo" (todas las categorías).
  final String? selectedCategorySlug;

  /// cash | transfer — Nequi gateway no existe en presencial.
  final AdminPaymentMethod paymentMethod;

  /// Celular que recibe el push transfer — ^3\d{9}$ (exigido solo
  /// en transfer, prohibido en cash).
  final String payerPhone;

  /// Nota del pedido completo — opcional, maxLength 500 (items[].notes
  /// no existe en V1 — fuera de alcance §042).
  final String notes;

  /// POST /admin/orders en vuelo — el CTA muestra spinner inline y
  /// bloquea el doble-tap (sin clientRequestId, el busy es la
  /// idempotencia — §042).
  final bool submitting;

  /// Celular colombiano del contrato — mismo regex del checkout.
  static final RegExp _colombianMobile = RegExp(r'^3\d{9}$');

  int get total => items.fold(0, (s, i) => s + i.lineTotal);
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// La mesa elegida resuelta del listado — tras un resync su
  /// `isFree` re-valida sola (tableAvailable).
  AdminTable? get selectedTable {
    for (final t in tables) {
      if (t.id == selectedTableId) return t;
    }
    return null;
  }

  /// ¿La mesa elegida sigue aceptando pedido? Se re-valida al
  /// cobrar con las mesas más frescas — una mesa que quedó ocupada
  /// o inactiva entre el load y el submit invalida sola.
  bool get tableAvailable => selectedTable?.isFree ?? false;

  bool get isPayerPhoneValid => _colombianMobile.hasMatch(payerPhone.trim());

  /// Puerta del "Crear pedido": ítems no vacíos + (pickup | mesa
  /// libre elegida) + (cash | celular válido) — y sin submit en
  /// vuelo (busy).
  bool get canSubmit =>
      items.isNotEmpty &&
      !submitting &&
      (serviceType == AdminServiceType.pickup || tableAvailable) &&
      (paymentMethod == AdminPaymentMethod.cash || isPayerPhoneValid);

  /// Productos visibles con el filtro de categoría — "Todo" (null)
  /// aplana la carta completa.
  List<CatalogProduct> get visibleProducts => [
    for (final c in categories)
      if (selectedCategorySlug == null || c.slug == selectedCategorySlug)
        ...c.products,
  ];

  /// Unidades del producto ya en el ticket (suma de las filas con
  /// ese productId) — el pick row muestra stepper en vez de "+"
  /// cuando ya hay.
  int productUnits(String productId) => items
      .where((i) => i.productId == productId)
      .fold(0, (s, i) => s + i.quantity);

  AdminNewOrderState copyWith({
    List<CatalogCategory>? categories,
    List<AdminTable>? tables,
    bool? loading,
    bool? failed,
    List<CartItem>? items,
    AdminNewOrderStep? step,
    AdminServiceType? serviceType,
    String? Function()? selectedTableId,
    String? Function()? selectedCategorySlug,
    AdminPaymentMethod? paymentMethod,
    String? payerPhone,
    String? notes,
    bool? submitting,
  }) => AdminNewOrderState(
    categories: categories ?? this.categories,
    tables: tables ?? this.tables,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    items: items ?? this.items,
    step: step ?? this.step,
    serviceType: serviceType ?? this.serviceType,
    selectedTableId: selectedTableId != null
        ? selectedTableId()
        : this.selectedTableId,
    selectedCategorySlug: selectedCategorySlug != null
        ? selectedCategorySlug()
        : this.selectedCategorySlug,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    payerPhone: payerPhone ?? this.payerPhone,
    notes: notes ?? this.notes,
    submitting: submitting ?? this.submitting,
  );

  @override
  List<Object?> get props => [
    categories,
    tables,
    loading,
    failed,
    items,
    step,
    serviceType,
    selectedTableId,
    selectedCategorySlug,
    paymentMethod,
    payerPhone,
    notes,
    submitting,
  ];
}
