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
    Set<String>? extras,
    Set<String>? toppings,
    Set<String>? sauces,
    Map<String, String>? replacements,
  }) : removed = removed ?? <String>{},
       extras = extras ?? <String>{},
       toppings = toppings ?? <String>{},
       sauces = sauces ?? <String>{},
       replacements = replacements ?? <String, String>{};

  final Set<String> removed;
  final Set<String> extras;
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
    final addedIds = <String>{};
    for (final m in item.modifiers) {
      switch (m.action) {
        case CartModifierAction.removed:
          removed.add(m.optionId);
        case CartModifierAction.added:
          if (m.replacesOptionId != null) {
            replacements[m.replacesOptionId!] = m.optionId;
          } else {
            addedIds.add(m.optionId);
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

    final extras = <String>{};
    final toppings = <String>{};
    final sauces = <String>{};
    for (final id in addedIds) {
      switch (groupOf(id)) {
        case 'extras':
          extras.add(id);
        case 'toppings':
          toppings.add(id);
        case 'sauces':
          sauces.add(id);
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
