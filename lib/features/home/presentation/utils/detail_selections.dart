import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../domain/entities/catalog_product.dart';

/// Las 5 colecciones de selección del detalle (§018) como valor —
/// el modo edición las reconstruye desde un CartItem (§021).
///
/// Los sets se crean MUTABLES por defecto (el detalle los alterna
/// con _toggle) — un `const {}` sería inmodificable en runtime.
class DetailSelections {
  DetailSelections({
    Set<String>? removed,
    Map<String, int>? extras,
    Set<String>? toppings,
    Set<String>? sauces,
    Map<String, String>? replacements,
  }) : removed = removed ?? <String>{},
       extras = extras ?? <String, int>{},
       toppings = toppings ?? <String>{},
       sauces = sauces ?? <String>{},
       replacements = replacements ?? <String, String>{};

  final Set<String> removed;
  /// optionId → porciones (§045) — solo extras cobrados; ≥ 1, sin
  /// tope. Un id ausente = no seleccionado.
  final Map<String, int> extras;
  final Set<String> toppings;
  final Set<String> sauces;
  final Map<String, String> replacements;

  /// Reconstruye las selecciones desde las filas del CartItem:
  /// - removed → _removed
  /// - added con replacesOptionId → _replacements[replaces] = optionId
  /// - added sin replaces → grupo del optionId decide extras/toppings/
  ///   sauces (los grupos del producto se consultan por id)
  /// - removed cuya id aparece como `replacesOptionId` de otra fila →
  ///   NO va a _removed: en el modo agregar el agotado vive solo en
  ///   _replacements (revisor-ui §021 — tenerlo en ambos emitía el
  ///   `removed` duplicado al guardar y lo tachaba distinto).
  factory DetailSelections.fromCartItem(CartItem item, CatalogProduct product) {
    final removed = <String>{};
    final replacements = <String, String>{};
    final addedById = <String, CartModifier>{};
    for (final m in item.modifiers) {
      switch (m.action) {
        case CartModifierAction.removed:
          removed.add(m.optionId);
        case CartModifierAction.added:
          if (m.replacesOptionId != null) {
            replacements[m.replacesOptionId!] = m.optionId;
          } else {
            addedById[m.optionId] = m;
          }
      }
    }
    removed.removeAll(replacements.keys);
    String? groupOf(String id) {
      for (final o in product.additionalOptions) {
        if (o.id == id) return 'extras';
      }
      for (final o in product.toppingOptions) {
        if (o.id == id) return 'toppings';
      }
      for (final o in product.sauceOptions) {
        if (o.id == id) return 'sauces';
      }
      return null;
    }

    final extras = <String, int>{};
    final toppings = <String>{};
    final sauces = <String>{};
    for (final e in addedById.entries) {
      switch (groupOf(e.key)) {
        case 'extras':
          // times del snapshot (§045) — las filas viejas vienen en 1.
          extras[e.key] = e.value.times;
        case 'toppings':
          toppings.add(e.key);
        case 'sauces':
          sauces.add(e.key);
        case null:
          break; // opción ya no existe — la edición la descarta
      }
    }
    return DetailSelections(
      removed: removed,
      extras: extras,
      toppings: toppings,
      sauces: sauces,
      replacements: replacements,
    );
  }
}
