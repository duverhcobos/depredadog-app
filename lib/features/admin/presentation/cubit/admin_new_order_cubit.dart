import 'dart:async' show FutureRecord2, unawaited;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cart/domain/entities/cart_item.dart';
import '../../../home/domain/use_cases/get_catalog_menu_use_case.dart';
import '../../domain/entities/admin_new_order_draft.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/use_cases/create_admin_order_use_case.dart';
import '../../domain/use_cases/load_admin_tables_use_case.dart';
import 'admin_new_order_state.dart';

/// Cubit de la comanda presencial (§042) — registrado como FACTORY:
/// cada entrada a /admin/orders/new obtiene un borrador limpio y el
/// abandonado muere con la pantalla (a diferencia del singleton de
/// la cola).
class AdminNewOrderCubit extends Cubit<AdminNewOrderState> {
  AdminNewOrderCubit({
    required this._getMenu,
    required this._loadTables,
    required this._createOrder,
  }) : super(const AdminNewOrderState());

  final GetCatalogMenuUseCase _getMenu;
  final LoadAdminTablesUseCase _loadTables;
  final CreateAdminOrderUseCase _createOrder;

  /// Cantidad máxima por ítem — `items[].quantity` del DTO admite
  /// 1..20 (backend §019).
  static const int _maxQuantity = 20;

  /// Ids locales `comanda-<n>` del borrador — keys de lista y
  /// removeItem/setItemQty (misma convención del `cart-<n>`).
  int _seq = 0;

  /// Carga inicial: carta + mesas en PARALELO (Future.wait sobre los
  /// dos Either). Left en cualquiera → vista de error con Reintentar
  /// (misma convención de la cola §038).
  Future<void> load() async {
    emit(state.copyWith(loading: true, failed: false));
    // `.wait` sobre el record = Future.wait con el tipo de cada
    // Either intacto (CatalogFailure vs AdminFailure no comparten L).
    final (menu, tables) = await (_getMenu(), _loadTables()).wait;
    if (menu.isLeft() || tables.isLeft()) {
      emit(state.copyWith(loading: false, failed: true));
      return;
    }
    emit(
      state.copyWith(
        categories: menu.getOrElse(() => const []),
        tables: tables.getOrElse(() => const []),
        loading: false,
        failed: false,
      ),
    );
  }

  /// Agrega el ítem armado en el sheet — merge por
  /// `sameConfiguration` (misma regla del carrito: mismo producto +
  /// mismos mods suma qty, no duplica fila) con tope 20 del DTO.
  void addItem(CartItem item) {
    final items = List<CartItem>.of(state.items);
    final i = items.indexWhere((e) => e.sameConfiguration(item));
    if (i >= 0) {
      final qty = (items[i].quantity + item.quantity).clamp(1, _maxQuantity);
      items[i] = items[i].copyWith(quantity: qty);
    } else {
      items.add(item.copyWith(id: 'comanda-${++_seq}'));
    }
    emit(state.copyWith(items: items));
  }

  void removeItem(String itemId) => emit(
    state.copyWith(items: state.items.where((i) => i.id != itemId).toList()),
  );

  /// Cantidad directa del stepper del ticket — <=0 elimina (misma
  /// convención del carrito), el tope 20 del DTO se respeta.
  void setItemQty(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    emit(
      state.copyWith(
        items: [
          for (final i in state.items)
            i.id == itemId
                ? i.copyWith(quantity: quantity.clamp(1, _maxQuantity))
                : i,
        ],
      ),
    );
  }

  /// Filtro de la comanda — null = "Todo".
  void selectCategory(String? slug) =>
      emit(state.copyWith(selectedCategorySlug: () => slug));

  /// Mesa | Para llevar. Cambiar a pickup limpia la mesa elegida
  /// (tableId prohibido ahí); volver a dineIn exige re-elegir.
  void toggleService(AdminServiceType serviceType) {
    if (serviceType == state.serviceType) return;
    emit(
      state.copyWith(
        serviceType: serviceType,
        selectedTableId: serviceType == AdminServiceType.pickup
            ? () => null
            : () => state.selectedTableId,
      ),
    );
  }

  /// Elige mesa solo si sigue libre (activa + sin pedido vivo) —
  /// una ocupada/inactiva no entra al borrador ni por tap perdido.
  void selectTable(String tableId) {
    for (final t in state.tables) {
      if (t.id == tableId && t.isFree) {
        emit(state.copyWith(selectedTableId: () => tableId));
        return;
      }
    }
  }

  /// Efectivo | Transf. — pasar a cash deja el celular tipeado (si
  /// vuelve a Transf. no tiene que reescribir), pero el draft no lo
  /// manda porque payerPhone solo viaja en transfer.
  void setPayment(AdminPaymentMethod method) =>
      emit(state.copyWith(paymentMethod: method));

  void setPayerPhone(String value) => emit(state.copyWith(payerPhone: value));

  void setNotes(String value) => emit(state.copyWith(notes: value));

  /// Comanda → Cobro — exige ítems (el CTA de comanda ya viene
  /// disabled en 0; la puerta queda por si entra por teclado).
  void goToCobro() {
    if (state.items.isEmpty) return;
    emit(state.copyWith(step: AdminNewOrderStep.cobro));
  }

  void backToComanda() => emit(state.copyWith(step: AdminNewOrderStep.comanda));

  /// "Crear pedido" — POST /admin/orders (§042). Devuelve la orden
  /// creada o el failure para que la pantalla tostee por código:
  /// ORDER_CATALOG_VIOLATION (un ítem se agotó en el medio),
  /// TABLE_NOT_FOUND (la mesa quedó ocupada/inactiva → resync de
  /// mesas + elige otra), PAYMENT_DISPATCH_FAILED (el push transfer
  /// no salió) o genérico. El éxito lo muestra el load() de la cola.
  Future<AdminNewOrderSubmit> submit() async {
    if (!state.canSubmit) return (order: null, failure: null);
    emit(state.copyWith(submitting: true));
    final result = await _createOrder(
      AdminNewOrderDraft(
        serviceType: state.serviceType,
        tableId: state.serviceType == AdminServiceType.dineIn
            ? state.selectedTableId
            : null,
        paymentMethod: state.paymentMethod,
        payerPhone: state.paymentMethod == AdminPaymentMethod.transfer
            ? state.payerPhone.trim()
            : null,
        items: state.items,
        notes: state.notes,
      ),
    );
    return result.fold(
      (failure) {
        emit(state.copyWith(submitting: false));
        // TABLE_NOT_FOUND → las mesas cambiaron debajo de la comanda;
        // resync silencioso para que el picker muestre la verdad al
        // re-elegir (si el resync falla se queda con las viejas —
        // el toast ya explica la situación). Si la mesa elegida
        // quedó ocupada en el resync, se suelta — conservarla
        // seleccionada-deshabilitada confunde (revisor-ui §042).
        if (failure.errorCode == 'TABLE_NOT_FOUND') {
          unawaited(
            _loadTables().then((r) {
              if (isClosed) return;
              r.fold((_) {}, (tables) {
                final stillFree = tables.any(
                  (t) => t.id == state.selectedTableId && t.isFree,
                );
                emit(
                  state.copyWith(
                    tables: tables,
                    selectedTableId: () =>
                        stillFree ? state.selectedTableId : null,
                  ),
                );
              });
            }),
          );
        }
        return (order: null, failure: failure);
      },
      // Éxito — libera el busy por simetría con la rama de fallo:
      // si el pop se cancelara el CTA no queda congelado (revisor).
      (order) {
        emit(state.copyWith(submitting: false));
        return (order: order, failure: null);
      },
    );
  }
}
