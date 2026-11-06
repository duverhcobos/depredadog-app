import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_modifier.dart';
import 'cart_state.dart';

/// SOLID (SRP): único dueño del carrito en construcción. Singleton
/// sobre el shell (misma posición que CatalogCubit) — una instancia
/// sirve badge, pantalla de carrito y el futuro checkout. Estado en
/// memoria: NO persiste entre arranques (decisión MVP §020).
///
/// Los métodos son síncronos — toda la mutación es local e
/// instantánea; el cubit no tiene async gap que proteger.
/// Resultado de `editItem` (§021): la pantalla elige el toast —
/// un merge es invisible en la lista (la fila editada se fusiona
/// con otra igual) y un "Cambios guardados" a secas mentiría.
enum CartEditOutcome {
  /// Config nueva guardada (in-place, reemplazo de fila o split).
  updated,

  /// La config editada era idéntica a OTRA fila — cantidades
  /// fusionadas y la fila editada desapareció.
  merged,
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  int _seq = 0;

  /// Agrega un ítem con id propio `cart-<n>` (determinista para
  /// keys y tests). Si ya existe una fila con la MISMA
  /// configuración (producto + conjunto de modificadores), suma
  /// cantidad en esa fila en vez de duplicar.
  void addItem({
    required String productId,
    required String productSlug,
    required String productName,
    required int unitBase,
    required List<CartModifier> modifiers,
    List<String> includedNames = const [],
    String? imageUrl,
  }) {
    final draft = CartItem(
      id: '',
      productId: productId,
      productSlug: productSlug,
      productName: productName,
      imageUrl: imageUrl,
      unitBase: unitBase,
      modifiers: modifiers,
      includedNames: includedNames,
    );
    final items = List<CartItem>.of(state.items);
    final i = items.indexWhere((e) => e.sameConfiguration(draft));
    if (i >= 0) {
      items[i] = items[i].copyWith(quantity: items[i].quantity + 1);
    } else {
      items.add(draft.copyWith(id: 'cart-${++_seq}'));
    }
    emit(CartState(items: items));
  }

  /// Cambia la cantidad de una fila — `quantity <= 0` elimina
  /// (el − del stepper en 1 quita el ítem, patrón estándar).
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    emit(
      CartState(
        items: [
          for (final i in state.items)
            i.id == itemId ? i.copyWith(quantity: quantity) : i,
        ],
      ),
    );
  }

  /// Guarda la edición de la personalización (§021). applyToAll=true
  /// reemplaza los modifiers de TODA la fila; false separa 1 unidad
  /// con la nueva config (la original queda qty-1). Si el resultado
  /// coincide con OTRA fila existente, se fusionan cantidades — la
  /// misma regla de merge de addItem (en ese caso devuelve
  /// `CartEditOutcome.merged` para que el toast lo explique).
  /// Config sin cambios reales = no-op en el mismo lugar.
  CartEditOutcome editItem({
    required String itemId,
    required List<CartModifier> modifiers,
    required List<String> includedNames,
    required bool applyToAll,
  }) {
    final items = List<CartItem>.of(state.items);
    final i = items.indexWhere((e) => e.id == itemId);
    if (i < 0) return CartEditOutcome.updated;
    final original = items[i];
    final edited = original.copyWith(
      modifiers: modifiers,
      includedNames: includedNames,
      quantity: applyToAll ? original.quantity : 1,
    );
    // Sin cambios de config → reemplazo en el mismo índice.
    if (edited.sameConfiguration(original)) {
      items[i] = edited;
      emit(CartState(items: items));
      return CartEditOutcome.updated;
    }
    items.removeAt(i);
    // Split: la original sobrevive con qty-1 en su índice; la editada
    // entra JUSTO DESPUÉS (adyacente a su origen, no al final —
    // revisor-estetico §021). Con applyToAll la editada ocupa el
    // índice de la original.
    var insertAt = i;
    if (!applyToAll && original.quantity > 1) {
      items.insert(i, original.copyWith(quantity: original.quantity - 1));
      insertAt = i + 1;
    }
    final j = items.indexWhere(
      (e) => e.id != itemId && e.sameConfiguration(edited),
    );
    if (j >= 0) {
      items[j] = items[j].copyWith(
        quantity: items[j].quantity + edited.quantity,
      );
      emit(CartState(items: items));
      return CartEditOutcome.merged;
    }
    items.insert(insertAt, edited.copyWith(id: 'cart-${++_seq}'));
    emit(CartState(items: items));
    return CartEditOutcome.updated;
  }

  void removeItem(String itemId) =>
      emit(CartState(items: state.items.where((i) => i.id != itemId).toList()));

  /// Vacía el carrito — checkout exitoso (§021) y un futuro
  /// "vaciar" manual lo usan.
  void clear() => emit(const CartState());
}
