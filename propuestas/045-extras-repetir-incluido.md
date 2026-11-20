# Propuesta: Extras repetibles con contador de porciones

Regla de negocio del usuario: **la gente puede repetir un ingrediente
como adicional, incluido o no, en N porciones** (doble/triple
mozzarella…). Revisión interactiva aplicada:

- Repetible = cualquier opción incluida **con `extraPrice > 0`** (pan y
  salchicha quedan fuera — su precio extra es 0, no se venden sueltos).
- Porciones con **contador**, no toggle binario — **sin tope**
  (decisión del usuario: "la gente puede repetir" no tiene límite).
- Conflicto "quitar + extra de lo mismo": al quitar se limpia su extra y
  la fila de Adicionales se deshabilita mientras esté quitada.
- Duplicado visual incluido/extra: **sin marca** — la sección ya da el
  contexto (si la revisión visual lo pide, se agrega hint después).

Depende del backend **§026** (`times` en `OrderItemModifierDto` +
`priceDelta` = total de línea + `times` en `order_item_modifiers` y en
la respuesta). El campo es opcional server-side: mientras §026 no esté
en prod el payload sin `times` sigue funcionando — pero el stepper solo
tiene sentido con §026 desplegado.

UX: las filas de Adicionales cambian de toggle a **stepper − N +**
reutilizando `QuantityStepper` (§020, botones 44dp, tooltips
`cartStepperRemove/Add/Qty` existentes — **cero claves i18n nuevas**).
Con N=0 el − no hace nada (clamp); el precio de la fila muestra el total
`extra × N` cuando N ≥ 1, si no el unitario.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/home/domain/entities/catalog_product.dart` | `additionalOptions` admite incluidas con precio + `kMaxExtraTimes` |
| `lib/features/home/presentation/utils/detail_selections.dart` | `extras` Set→Map\<String,int\>, `fromCartItem` lee times |
| `lib/features/cart/domain/entities/cart_modifier.dart` | campo `times` (snapshot porciones) |
| `lib/features/home/presentation/screens/product_detail_screen.dart` | sección Adicionales con stepper + guards |
| `lib/features/home/presentation/widgets/extra_stepper_row.dart` | **nuevo** — fila nombre+precio+stepper |
| `lib/features/checkout/domain/use_cases/create_order_params.dart` | `times` en el param de modificador |
| `lib/features/checkout/presentation/cubit/checkout_cubit.dart` | mapea `m.times` al param |
| `lib/features/checkout/data/repositories/checkout_repository_impl.dart` | `'times'` en el JSON del pedido |
| `lib/features/orders/data/models/order_item_modifier_mapper.dart` | parsea `times` de la respuesta |
| `lib/features/cart/presentation/widgets/cart_item_detail_panel.dart` | extras muestran "×N" |
| `lib/features/admin/presentation/utils/kitchen_order_data.dart` | card de cocina "Nombre ×N" |
| `lib/features/admin/presentation/widgets/new_order/item_customize_sheet.dart` | mismo stepper + guard en el sheet admin |
| `test/features/home/presentation/detail_selections_test.dart` | round-trip de times en edición |
| `test/…catalog…` | asserts del filtro nuevo de `additionalOptions` |

**i18n:** sin claves nuevas (tooltips del stepper ya existen).
**DI / rutas:** sin cambios.

---

## 1. `catalog_product.dart` (existente — actualización)

**Ruta:** `lib/features/home/domain/entities/catalog_product.dart`

**Antes:**
```dart
  /// "¿Le agregamos algo más?": las que NO vienen por defecto, más los
  /// fijos con precio (doble salchicha — incluida/no removible pero
  /// cobrada si se repite; el pan no entra porque su precio es 0).
  List<ModifierOption> get additionalOptions =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where(
            (o) => !o.includedByDefault || (!o.isRemovable && o.extraPrice > 0),
          )
          .toList();
```

**Después:**
```dart
  /// "¿Le agregamos algo más?": las que NO vienen por defecto, más TODA
  /// incluida con precio — cualquier ingrediente del perro se repite
  /// pagándolo como adicional (§045). Pan y salchicha quedan fuera
  /// porque su extra_price es 0 — no se venden sueltos.
  List<ModifierOption> get additionalOptions =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where((o) => !o.includedByDefault || o.extraPrice > 0)
          .toList();
```

Y en la sección de constantes del archivo (junto a `ModifierGroupSlugs`):

```dart
/// Mínimo de porciones al agregar un adicional (§045) — no hay tope
/// superior (decisión del usuario); el stepper solo clampa por abajo.
const int kMinExtraTimes = 1;
```

## 2. `cart_modifier.dart` (existente — actualización)

**Ruta:** `lib/features/cart/domain/entities/cart_modifier.dart`

**Antes:**
```dart
  const CartModifier({
    required this.optionId,
    required this.optionName,
    required this.action,
    required this.priceDelta,
    this.replacesOptionId,
    this.group,
  });
```
…
```dart
  /// Grupo de origen de la opción (§021b) — el panel secciona con él.
  /// Null en filas viejas/fixtures: una `added` sin etiqueta cae a
  /// Adicionales (fallback razonable). Tampoco entra a
  /// sameConfiguration — una opción nunca vive en dos grupos.
  final CartModifierGroup? group;

  @override
  List<Object?> get props => [
    optionId,
    optionName,
    action,
    priceDelta,
    replacesOptionId,
    group,
  ];
```

**Después:**
```dart
  const CartModifier({
    required this.optionId,
    required this.optionName,
    required this.action,
    required this.priceDelta,
    this.times = 1,
    this.replacesOptionId,
    this.group,
  });
```
…
```dart
  /// Grupo de origen de la opción (§021b) — el panel secciona con él.
  /// Null en filas viejas/fixtures: una `added` sin etiqueta cae a
  /// Adicionales (fallback razonable). Tampoco entra a
  /// sameConfiguration — una opción nunca vive en dos grupos.
  final CartModifierGroup? group;

  /// Porciones del adicional (§045) — solo aplica a `added` de extras
  /// cobrados; `priceDelta` ya es el total de línea (extra × times).
  /// Removed, toppings, salsas y reemplazos siempre son 1.
  final int times;

  @override
  List<Object?> get props => [
    optionId,
    optionName,
    action,
    priceDelta,
    times,
    replacesOptionId,
    group,
  ];
```

## 3. `detail_selections.dart` (existente — actualización)

**Ruta:** `lib/features/home/presentation/utils/detail_selections.dart`

**Antes:**
```dart
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
```

**Después:**
```dart
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
```

Y en `fromCartItem`, el bloque que reparte `addedIds`:

**Antes:**
```dart
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
```
…
```dart
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
```

**Después:**
```dart
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
```
…
```dart
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
```

## 4. `extra_stepper_row.dart` (archivo nuevo)

**Ruta:** `lib/features/home/presentation/widgets/extra_stepper_row.dart`

```dart
import 'package:flutter/material.dart';

import '../../../cart/presentation/widgets/quantity_stepper.dart';
import '../../../../core/utils/formatters.dart';

/// Fila de adicional con contador de porciones (§045): nombre + precio
/// (total `extra × N` cuando hay selección, unitario cuando no) +
/// stepper reutilizado del carrito. `enabled=false` la deja gris —
/// opción agotada o quitada del perro.
class ExtraStepperRow extends StatelessWidget {
  const ExtraStepperRow({
    required this.label,
    required this.unitPrice,
    required this.times,
    required this.onChanged,
    required this.enabled,
    this.disabledLabel,
    super.key,
  });

  final String label;
  final int unitPrice;
  final int times;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Texto del trailing cuando no está disponible (ej. "Agotado").
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = enabled ? null : colors.onSurface.withValues(alpha: 0.38);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            ),
            Text(
              disabledLabel ??
                  '+${formatCop(times > 0 ? unitPrice * times : unitPrice)}',
              style: text.bodySmall?.copyWith(
                color: muted ?? colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            IgnorePointer(
              ignoring: !enabled,
              child: QuantityStepper(quantity: times, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}
```

Nota de implementación: ajustar imports (`formatCop` vive en
`lib/core/utils/` — usar la ruta real del proyecto) y el
`withValues(alpha:)` según la versión de Flutter del repo.

## 5. `product_detail_screen.dart` (existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/product_detail_screen.dart`

### 5a. Total del preview — extras multiplican

**Antes** (~línea 90):
```dart
      if (_sel.extras.contains(o.id)) t += o.extraPrice;
```

**Después:**
```dart
      final n = _sel.extras[o.id];
      if (n != null) t += o.extraPrice * n;
```

### 5b. `_swapCandidates` — las incluidas no son reemplazo gratis

**Antes:**
```dart
    return (_item?.additionalOptions ?? const <ModifierOption>[]).where(
      (e) =>
          e.isAvailable &&
          e.isReplacementEligible &&
          (_sel.replacements[exhaustedId] == e.id ||
              !_sel.replacements.containsValue(e.id)),
    );
```

**Después:**
```dart
    return (_item?.additionalOptions ?? const <ModifierOption>[]).where(
      // !includedByDefault: reemplazar = cambiar lo incluido por algo
      // que NO viene — una incluida ya está en el perro (§045 las
      // incluidas entraron a additionalOptions como extra cobrado).
      (e) =>
          !e.includedByDefault &&
          e.isAvailable &&
          e.isReplacementEligible &&
          (_sel.replacements[exhaustedId] == e.id ||
              !_sel.replacements.containsValue(e.id)),
    );
```

### 5c. Guard quitar→limpia su extra

**Antes** (RemovableRow ~línea 439):
```dart
                                    onTap: () => _toggle(_sel.removed, o.id),
```

**Después:**
```dart
                                    // Quitar también limpia su extra
                                    // (§045): "sin X pero con X extra"
                                    // es inválido — el backend lo
                                    // rechaza con duplicate modifier.
                                    onTap: () {
                                      _toggle(_sel.removed, o.id);
                                      _sel.extras.remove(o.id);
                                    },
```

### 5d. Sección Adicionales con stepper

**Antes** (~líneas 535–545):
```dart
                              for (final o in extras)
                                OptionRow(
                                  label: o.name,
                                  trailingLabel: o.isAvailable
                                      ? '+${formatCop(o.extraPrice)}'
                                      : l10n.catalogSoldOut,
                                  selected: _sel.extras.contains(o.id),
                                  enabled: o.isAvailable,
                                  onTap: () => _toggle(_sel.extras, o.id),
                                ),
```

**Después:**
```dart
                              for (final o in extras)
                                ExtraStepperRow(
                                  label: o.name,
                                  unitPrice: o.extraPrice,
                                  times: _sel.extras[o.id] ?? 0,
                                  disabledLabel:
                                      o.isAvailable ? null : l10n.catalogSoldOut,
                                  // Agotada, o quitada del perro (§045):
                                  // no se puede pedir su extra.
                                  enabled:
                                      o.isAvailable &&
                                      !_sel.removed.contains(o.id),
                                  onChanged: (n) => setState(() {
                                    // Sin tope (§045) — clamp solo por
                                    // abajo: 0 o menos quita el extra.
                                    if (n < kMinExtraTimes) {
                                      _sel.extras.remove(o.id);
                                    } else {
                                      _sel.extras[o.id] = n;
                                    }
                                  }),
                                ),
```

### 5e. `_buildModifiers` — extras emiten `times` y delta total

**Antes** (~líneas 186–193):
```dart
      for (final id in _sel.extras)
        ?mod(
          id,
          CartModifierAction.added,
          _optionById(item, id)?.extraPrice ?? 0,
          null,
          CartModifierGroup.extra,
        ),
```

**Después:**
```dart
      for (final e in _sel.extras.entries)
        ?mod(
          e.key,
          CartModifierAction.added,
          (_optionById(item, e.key)?.extraPrice ?? 0) * e.value,
          null,
          CartModifierGroup.extra,
          times: e.value,
        ),
```

Ajustar la firma del helper local `mod(...)` para aceptar `times`
(named opcional, default 1) y pasarlo al `CartModifier`.

## 6. Checkout — `times` llega al payload

- `create_order_params.dart`: el param de modificador agrega
  `this.times = 1` + `final int times;` (doc: porciones del extra §045).
- `checkout_cubit.dart` (~línea 450): `times: m.times` al construir el
  param.
- `checkout_repository_impl.dart` (~línea 64): agregar
  `'times': m.times` al map del modificador — siempre se envía (el
  backend también acepta su ausencia = 1).

## 7. Respuesta de pedidos — `times` vuelve al cart item

`order_item_modifier_mapper.dart`: leer `m['times']` (`as int? ?? 1`)
y pasarlo al `CartModifier` — el detalle de un pedido creado (panel,
card de cocina) muestra las porciones reales.

## 8. Displays "×N"

- `cart_item_detail_panel.dart`: en la fila de cada extra, anteponer
  `×${m.times} ` al nombre **solo cuando `m.times > 1`** — el precio
  (`+formatCop(m.priceDelta)`) ya es total de línea.
- `kitchen_order_data.dart` (`extras` ~línea 181): cada nombre se
  construye `m.times > 1 ? '${m.optionName} ×${m.times}' : m.optionName`
  — la card de cocina muestra "Mozzarella ×2".

## 9. Sheet admin `item_customize_sheet.dart` (existente — actualización)

**Ruta:** `lib/features/admin/presentation/widgets/new_order/item_customize_sheet.dart`

Mismo patrón que el detalle (el dueño también vende porciones dobles):

- `final Set<String> _extras` → `final Map<String, int> _extras = {}`.
- `_total` (~línea 65): `t += o.extraPrice * (_extras[o.id] ?? 0)` —
  reescribir el `for` sobre `_extras.values`/`entries`.
- `_build` de modificadores (~línea 105): iterar `_extras.entries`,
  `priceDelta = o.extraPrice * n` + `times: n` en el `CartModifier`.
- Filas de extras (~línea 254): `OptionRow` → `ExtraStepperRow` con la
  misma lógica de `enabled` (agotada o quitada) y `onChanged` del 5d.
- El toggle de "quitar" del sheet limpia `_extras.remove(o.id)` — mismo
  guard 5c.

## 10. Tests

- `detail_selections_test.dart`: el caso "doble salchicha" pasa a
  verificar `sel.extras['o-salchicha'] == 1`; agregar caso con
  `CartModifier(times: 2)` → `sel.extras[…] == 2`.
- Test de entidad (donde se cubra `additionalOptions`): incluida +
  removible + `extraPrice > 0` → SÍ; incluida + `extraPrice == 0` → NO;
  no incluida → SÍ.
- Fixtures que construyan `CartModifier` sin `times` siguen compilando
  (default 1).

---

## Orden de aplicación

1. `catalog_product.dart` (filtro + constante) — la entidad define todo
2. `cart_modifier.dart` (`times`)
3. `detail_selections.dart` (Map + fromCartItem)
4. `extra_stepper_row.dart` (widget nuevo)
5. `product_detail_screen.dart` (5a–5e)
6. Checkout params/cubit/repository
7. `order_item_modifier_mapper.dart`
8. Panel + `kitchen_order_data.dart`
9. `item_customize_sheet.dart` admin
10. Tests + `flutter analyze` + `flutter test`
11. Revisión visual del usuario en el emulador

**Orden de despliegue:** backend §026 primero (migration:run en prod +
Render live), después la app — un `times` mandado a un backend viejo
sería ignorado por class-validator y cobraría una sola porción.
