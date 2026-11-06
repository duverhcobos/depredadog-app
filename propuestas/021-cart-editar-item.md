# Propuesta: Carrito — desplegable de detalle + editar personalización (§021)

Pedido del usuario tras ver el carrito (§020): que cada fila muestre el detalle
completo de lo que lleva el perro — lo que lleva, lo que se quitó y lo que se
agregó — en un desplegable; y que si se equivocó pueda MODIFICAR la
personalización abriendo la pantalla del producto en modo edición (el CTA deja
de ser "Agregar al carrito" y pasa a "Guardar cambios").

Decisión del usuario para la semántica de cantidad: **al editar una fila con
`quantity > 1`, al tocar "Guardar cambios" se pregunta "¿A cuántos aplicar?"**
— `Solo 1` (separa una unidad con la nueva config) o `Las N` (cambia la fila
entera). Con `quantity == 1` se guarda directo sin preguntar.

**Cambios de modelo (app):**

- `CartModifier.replacesOptionId` (nullable): en la fila `added` de un
  reemplazo gratis marca qué agotado reemplaza — sin él, un reemplazo a $0 es
  indistinguible de un topping gratis y el modo edición no podría reconstruir
  `_replacements`. NO entra a la clave de `sameConfiguration` (a nivel plato,
  topping-gratis y reemplazo-gratis son el mismo perro → sí se fusionan).
- `CartItem.includedNames: List<String>`: snapshot de los ingredientes que
  quedaron EN el ítem (`includedByDefault` − quitados − reemplazados) — es lo
  que el desplegable muestra como "Lleva:". Se captura al agregar/guardar,
  cuando el producto del catálogo está a la mano.
- `CartCubit.editItem(...)`: reemplaza la personalización de una fila con la
  semántica de alcance (applyToAll / separa 1) + merge si la nueva config
  coincide con otra fila.

**Ruta nueva:** `/home/cart/edit` (hija de `cart`, slideUp) — extra =
`CartItem`; renderiza `ProductDetailScreen` en modo edición.

**Cambios de UX:**

- El desplegable del tile pasa a ser SIEMPRE expandible (siempre hay "Lleva"
  que auditar): chevron permanente; el colapsado muestra el resumen de
  modificaciones o "Tal cual de la carta" si no tiene. Se retira el
  TextPainter de la re-crítica (ya no hace falta medir overflow).
- Panel expandido: `Lleva:` (nombres unidos por coma), `Sin:` y `Extras:`
  (solo si aplican) + botón "Editar" a la derecha → push `/home/cart/edit`.
- Modo edición en el detalle: sets precargados desde el CartItem (removed /
  replacements / extras / toppings / sauces reconstruidos por optionId), CTA
  "Guardar cambios", flecha back = descarta. Al guardar con qty>1 →
  bottom sheet con `Solo 1` / `Las N`; luego toast "Cambios guardados" + pop
  al carrito.
- Si el producto ya no existe en el catálogo al entrar a editar → la vista
  `_ProductUnavailableView` existente lo cubre (no se puede editar, sí
  eliminar).

**Fuera de alcance:** persistencia del carrito, editar cantidad desde la
pantalla de edición (la cantidad sigue solo en el stepper del carrito),
"quitar una unidad suelta" como acción propia.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/cart/domain/entities/cart_modifier.dart` | +`replacesOptionId` |
| `lib/features/cart/domain/entities/cart_item.dart` | +`includedNames`, copyWith amplía |
| `lib/features/cart/presentation/cubit/cart_cubit.dart` | `addItem` +`includedNames`; +`editItem` |
| `lib/features/cart/presentation/widgets/cart_item_detail_panel.dart` | **nuevo** — panel Lleva/Sin/Extras + Editar |
| `lib/features/cart/presentation/widgets/cart_edit_scope_sheet.dart` | **nuevo** — bottom sheet "¿A cuántos aplicar?" |
| `lib/features/cart/presentation/widgets/cart_item_tile.dart` | desplegable permanente + panel |
| `lib/features/home/presentation/utils/detail_selections.dart` | **nuevo** — sets del detalle + prefill desde CartItem |
| `lib/features/home/presentation/screens/product_detail_screen.dart` | modo edición (param, prefill, CTA Guardar) |
| `lib/core/routes/app_router.dart` | ruta `cart/edit` con extra CartItem |
| `lib/l10n/app_es.arb` | +9 claves |
| `test/features/cart/presentation/cubit/cart_cubit_test.dart` | +casos editItem |
| `test/features/home/presentation/detail_selections_test.dart` | **nuevo** — prefill ida y vuelta |
| `test/features/cart/presentation/screens/cart_screen_test.dart` | +casos desplegable/editar |
| `test/features/home/presentation/product_detail_screen_test.dart` | +casos modo edición |
| `Design/design-system.yaml` | spec cart/tile + changelog 1.21.0 |

---

## 1. `cart_modifier.dart` (archivo existente — actualización)

**Ruta:** `lib/features/cart/domain/entities/cart_modifier.dart`

**Después** (se agrega el campo y su doc; constructor y props se actualizan):

```dart
class CartModifier extends Equatable {
  const CartModifier({
    required this.optionId,
    required this.optionName,
    required this.action,
    required this.priceDelta,
    this.replacesOptionId,
  });

  final String optionId;
  final String optionName;
  final CartModifierAction action;
  final int priceDelta;

  /// Solo en filas `added` de un reemplazo gratis: id del ingrediente
  /// agotado que esta opción reemplaza (§021). Sin él, el modo edición
  /// no puede distinguir "Tostacos gratis por mozzarella agotada" de
  /// "Tostacos gratis porque sí" — la fila added apunta al removed.
  /// No participa en sameConfiguration (a nivel plato es la misma
  /// personalización).
  final String? replacesOptionId;
```

y en `props` se agrega `replacesOptionId` al final de la lista.

## 2. `cart_item.dart` (archivo existente — actualización)

**Ruta:** `lib/features/cart/domain/entities/cart_item.dart`

**Antes:**

```dart
    required this.modifiers,
    this.imageUrl,
    this.quantity = 1,
  });
```

**Después:**

```dart
    required this.modifiers,
    this.includedNames = const [],
    this.imageUrl,
    this.quantity = 1,
  });
```

**Después** (campo + doc, tras `modifiers`):

```dart
  /// Ingredientes que el ítem LLEVA (includedByDefault − quitados −
  /// reemplazados) — snapshot para el desplegable "Lleva:" del tile
  /// (§021). Se captura al agregar/guardar con el producto a la mano.
  final List<String> includedNames;
```

y `copyWith` gana `List<CartModifier>? modifiers` y
`List<String>? includedNames` (con `?? this.` en el cuerpo) — hoy solo
copia `id`/`quantity`. `props` agrega `includedNames`.

## 3. `cart_cubit.dart` (archivo existente — actualización)

**Ruta:** `lib/features/cart/presentation/cubit/cart_cubit.dart`

- `addItem` gana `List<String> includedNames = const []` y lo pasa al
  draft.
- `copyWith` ahora acepta `modifiers`/`includedNames` (ver §2) — los
  merges existentes no cambian.

**Después** (método nuevo, tras `updateQuantity`):

```dart
  /// Guarda la edición de la personalización (§021). applyToAll=true
  /// reemplaza los modifiers de TODA la fila; false separa 1 unidad
  /// con la nueva config (la original queda qty-1). Si el resultado
  /// coincide con OTRA fila existente, se fusionan cantidades — la
  /// misma regla de merge de addItem. Config sin cambios reales =
  /// no-op en el mismo lugar (la fila no salta al final).
  void editItem({
    required String itemId,
    required List<CartModifier> modifiers,
    required List<String> includedNames,
    required bool applyToAll,
  }) {
    final items = List<CartItem>.of(state.items);
    final i = items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
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
      return;
    }
    items.removeAt(i);
    // Split: la original sobrevive con qty-1 antes del índice editado.
    if (!applyToAll && original.quantity > 1) {
      items.insert(i, original.copyWith(quantity: original.quantity - 1));
    }
    final j = items.indexWhere(
      (e) => e.id != itemId && e.sameConfiguration(edited),
    );
    if (j >= 0) {
      items[j] = items[j].copyWith(
        quantity: items[j].quantity + edited.quantity,
      );
    } else {
      items.add(edited.copyWith(id: 'cart-${++_seq}'));
    }
    emit(CartState(items: items));
  }
```

## 4. `cart_item_detail_panel.dart` (archivo nuevo)

**Ruta:** `lib/features/cart/presentation/widgets/cart_item_detail_panel.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_modifier.dart';

/// Panel del desplegable del tile (§021): el detalle completo del
/// perro — "Lleva" los ingredientes que quedaron, "Sin" los quitados,
/// "Extras" los agregados con su precio — más el botón Editar que
/// abre el detalle del producto en modo edición (/home/cart/edit).
class CartItemDetailPanel extends StatelessWidget {
  const CartItemDetailPanel({required this.item, super.key});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final label = text.bodySmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.45),
      fontWeight: FontWeight.w600,
    );
    final value = text.bodySmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.8),
    );
    final removed = item.modifiers
        .where((m) => m.action == CartModifierAction.removed)
        .map((m) => m.optionName)
        .join(' · ');
    final added = item.modifiers
        .where((m) => m.action == CartModifierAction.added)
        .map(
          (m) => m.priceDelta > 0
              ? '${m.optionName} +${formatCop(m.priceDelta)}'
              : m.optionName,
        )
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.includedNames.isNotEmpty)
            _line(l10n.cartDetailIncluded, item.includedNames.join(', '),
                label, value),
          if (removed.isNotEmpty)
            _line(l10n.cartDetailRemoved, removed, label, value),
          if (added.isNotEmpty)
            _line(l10n.cartDetailExtras, added, label, value),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.push('/home/cart/edit', extra: item),
              icon: Icon(
                Icons.edit_outlined,
                size: 16,
                color: colors.primary,
              ),
              label: Text(
                l10n.cartItemEdit,
                style: text.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String tag, String content, TextStyle? label, TextStyle? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$tag ', style: label),
            TextSpan(text: content, style: value),
          ],
        ),
      ),
    );
  }
}
```

Nota: la ruta `/home/cart/edit` se navega con `context.push` + `extra:
item` — el literal del path solo aparece aquí y en el router; la
constante `AuthGuard.cartEditRoute = '/home/cart/edit'` se agrega para
centralizarlo (navigation-routing).

## 5. `cart_edit_scope_sheet.dart` (archivo nuevo)

**Ruta:** `lib/features/cart/presentation/widgets/cart_edit_scope_sheet.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Bottom sheet "¿A cuántos aplicar?" (§021) — solo se muestra al
/// guardar la edición de una fila con quantity > 1 (decisión del
/// usuario: pregunta al guardar). Devuelve true = a todas, false =
/// solo 1 unidad, null = cancelado.
Future<bool?> showCartEditScopeSheet(
  BuildContext context, {
  required int quantity,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.cartEditScopeTitle,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.looks_one_rounded),
            title: Text(l10n.cartEditScopeOne),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: Text(l10n.cartEditScopeAll(quantity)),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
```

## 6. `cart_item_tile.dart` (archivo existente — actualización)

**Ruta:** `lib/features/cart/presentation/widgets/cart_item_tile.dart`

- Quitar el LayoutBuilder/TextPainter del resumen (ya no se mide
  overflow — el desplegable siempre está disponible) y quitar el
  `_chevronSlot`.
- La fila del resumen se convierte en el disparador PERMANENTE del
  desplegable: `InkWell` + `Row[Expanded(Text(summary o 'tal cual')),
  Icon(chevron _expanded ? expand_less : expand_more)]`. Cuando
  `item.modifiers.isEmpty` el texto es `l10n.cartItemAsIs`
  ("Tal cual de la carta") en el mismo estilo atenuado.
- Bajo esa fila, `if (_expanded) CartItemDetailPanel(item: item)`.
- Imports: `+ ../utils/cart_item_summary.dart` ya existe; `+
  cart_item_detail_panel.dart`; quitar `TextPainter` no necesita
  import (es material).

Fragmento — reemplaza el `if (summary.isNotEmpty) LayoutBuilder(...)`
actual por:

```dart
                          // Desplegable permanente (§021): siempre hay
                          // "Lleva" que auditar — chevron fijo; sin
                          // modificaciones el colapsado dice "Tal cual".
                          InkWell(
                            onTap: () =>
                                setState(() => _expanded = !_expanded),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    summary.isEmpty
                                        ? l10n.cartItemAsIs
                                        : summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _expanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  size: 16,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_expanded) CartItemDetailPanel(item: item),
```

## 7. `detail_selections.dart` (archivo nuevo)

**Ruta:** `lib/features/home/presentation/utils/detail_selections.dart`

Agrupa los 5 sets del detalle + el mapeo CartItem→sets del modo
edición (§021) — lógica pura testeable sin bombear la pantalla.

```dart
import '../../domain/entities/catalog_product.dart';
import '../../domain/entities/modifier_option.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/domain/entities/cart_modifier.dart';

/// Las 5 colecciones de selección del detalle (§018) como valor —
/// el modo edición las reconstruye desde un CartItem (§021).
class DetailSelections {
  DetailSelections({
    this.removed = const {},
    this.extras = const {},
    this.toppings = const {},
    this.sauces = const {},
    this.replacements = const {},
  });

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
  ///   también va a _removed (queda tachada con su reemplazo hijo)
  factory DetailSelections.fromCartItem(
    CartItem item,
    CatalogProduct product,
  ) {
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
```

## 8. `product_detail_screen.dart` (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/product_detail_screen.dart`

- Constructor: `const ProductDetailScreen({required this.productSlug, this.editingItem, super.key});`
  + `final CartItem? editingItem;` (null = modo agregar, §020).
- Los 5 sets privados se reemplazan por UN `DetailSelections _sel =
  DetailSelections()` — todas las referencias `_removed` → `_sel.removed`
  etc. (mismo comportamiento; el refactor habilita el prefill).
- Prefill lazy en build: antes de renderizar secciones, si
  `widget.editingItem != null && !_prefilled && item != null`:
  `_sel = DetailSelections.fromCartItem(widget.editingItem!, item);
  _prefilled = true;` — mutación directa mid-build (se aplica al mismo
  frame, sin setState). `bool _prefilled = false;` en el State.
- `_buildModifiers`: en el bloque de reemplazos, la fila `added` lleva
  `replacesOptionId: e.key`:
  `?mod(e.value, CartModifierAction.added, 0, e.key)` — el helper `mod`
  gana el parámetro opcional.
- Nuevo `_includedNames(CatalogProduct item)`: `includedByDefault` del
  producto menos `_sel.removed` menos keys de `_sel.replacements` →
  `map((o) => o.name).toList()`.
- `_addToCart` pasa `includedNames: _includedNames(item)` al cubit.
- `_saveEdit(CatalogProduct item)`:

```dart
  /// Guarda la edición sobre el CartItem original (§021). Con qty>1
  /// pregunta el alcance (decisión del usuario) — el sheet devuelve
  /// true=a todas / false=solo 1 / null=cancelado.
  Future<void> _saveEdit(CatalogProduct item) async {
    final l10n = AppLocalizations.of(context)!;
    final editing = widget.editingItem!;
    final mods = _buildModifiers(item);
    final names = _includedNames(item);
    var applyToAll = true;
    if (editing.quantity > 1) {
      final r = await showCartEditScopeSheet(
        context,
        quantity: editing.quantity,
      );
      if (r == null || !context.mounted) return;
      applyToAll = r;
    }
    context.read<CartCubit>().editItem(
      itemId: editing.id,
      modifiers: mods,
      includedNames: names,
      applyToAll: applyToAll,
    );
    AppToast.success(context, l10n.cartEditSaved);
    context.pop();
  }
```

- Footer: el CTA cambia según modo — `Text(editing ? l10n.cartEditSaveCta
  : l10n.detailAddToCart)` y `onPressed` → `_saveEdit(item)` vs
  `_addToCart(item)`. En modo edición el toast de éxito es
  `cartEditSaved` ("Cambios guardados"), no "Agregado al carrito", y el
  producto agotado deshabilita igual (no se puede guardar lo que ya no
  existe).
- Imports: `+ cart_item.dart`, `+ detail_selections.dart`,
  `+ cart_edit_scope_sheet.dart` (cart/presentation/widgets).

## 9. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

- En `AuthGuard` (archivo `lib/core/routes/auth_guard.dart`):
  `static const cartEditRoute = '/home/cart/edit';`
- Bajo la ruta `cart` existente, hija `edit`:

```dart
                  GoRoute(
                    path: 'cart',
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(state, const CartScreen()),
                    routes: [
                      // Edición del ítem (§021) — extra = CartItem.
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) {
                          final item = state.extra as CartItem;
                          return CustomTransitions.slideUp(
                            state,
                            ProductDetailScreen(
                              productSlug: item.productSlug,
                              editingItem: item,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
```

- Import de `cart_item.dart` en el router (ya importa CartCubit).

## 10. `app_es.arb` (archivo existente — actualización)

**Ruta:** `lib/l10n/app_es.arb` — +9 claves, luego `flutter gen-l10n`:

```json
  "cartItemAsIs": "Tal cual de la carta",
  "@cartItemAsIs": { "description": "Resumen colapsado del ítem sin personalización (desplegable §021)" },
  "cartDetailIncluded": "Lleva:",
  "@cartDetailIncluded": { "description": "Etiqueta del panel — ingredientes que lleva el ítem" },
  "cartDetailRemoved": "Sin:",
  "@cartDetailRemoved": { "description": "Etiqueta del panel — ingredientes quitados" },
  "cartDetailExtras": "Extras:",
  "@cartDetailExtras": { "description": "Etiqueta del panel — agregados del ítem" },
  "cartItemEdit": "Editar",
  "@cartItemEdit": { "description": "Botón del panel que abre la edición del ítem" },
  "cartEditSaveCta": "Guardar cambios",
  "@cartEditSaveCta": { "description": "CTA del detalle en modo edición (reemplaza 'Agregar al carrito')" },
  "cartEditSaved": "Cambios guardados",
  "@cartEditSaved": { "description": "Toast al guardar la edición del ítem" },
  "cartEditScopeTitle": "¿A cuántos aplicar?",
  "@cartEditScopeTitle": { "description": "Título del bottom sheet de alcance al editar qty>1" },
  "cartEditScopeOne": "Solo 1",
  "@cartEditScopeOne": { "description": "Opción del sheet — aplicar a una sola unidad" },
  "cartEditScopeAll": "Las {count}",
  "@cartEditScopeAll": {
    "description": "Opción del sheet — aplicar a todas las unidades",
    "placeholders": { "count": { "type": "int" } }
  }
```

## 11. Tests

- `cart_cubit_test.dart` (+4 casos): `editItem` qty1 reemplaza en el
  mismo índice; qty>1 `applyToAll:true` cambia toda la fila; qty>1
  `applyToAll:false` separa 1 y la nueva config se fusiona si ya
  existe otra fila igual; editar a config idéntica a otra fila fusiona
  y la fila no se duplica.
- `detail_selections_test.dart` (nuevo): CartItem con removed +
  reemplazo + extra + topping + salsa → los 5 sets se reconstruyen;
  optionId que ya no existe en el producto se descarta.
- `cart_screen_test.dart` (+2 casos): tap en el resumen despliega
  "Lleva:"/"Sin:"/"Extras:" + botón Editar; ítem sin personalización
  muestra "Tal cual de la carta".
- `product_detail_screen_test.dart` (+2 casos): modo edición precarga
  los sets (fila tachada / chips activos) y el CTA dice "Guardar
  cambios"; guardar con qty1 llama editItem y hace pop. El sheet de
  alcance se cubre indirecto por el cubit (caso qty>1 del cubit test).

## 12. Design system

`Design/design-system.yaml` → `screens.cart` spec describe el
desplegable permanente + panel; nueva subsección `product_detail`
modo edición; `components` +`cart_edit_scope_sheet`; changelog 1.21.0.

---

## Orden de aplicación

1. `cart_modifier.dart` + `cart_item.dart` (entidades).
2. `cart_cubit.dart` (`includedNames` + `editItem`).
3. `detail_selections.dart` (mapper).
4. `cart_item_detail_panel.dart` + `cart_edit_scope_sheet.dart` (widgets).
5. `cart_item_tile.dart` (desplegable permanente).
6. `product_detail_screen.dart` (modo edición + includedNames al agregar).
7. `auth_guard.dart` + `app_router.dart` (ruta `cart/edit`).
8. `app_es.arb` + `flutter gen-l10n`.
9. Tests nuevos/actualizados.
10. `flutter analyze` + `flutter test`; revisores; design-system yaml.
