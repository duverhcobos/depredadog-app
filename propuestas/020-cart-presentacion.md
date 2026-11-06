# Propuesta 020 — Carrito (presentación)

> **Fecha:** 2026-02-03
> **Estado:** Propuesta
> **Tipo:** Feature nueva — módulo orders, paso 1 de 3
> **Origen:** El módulo orders arranca por el carrito: estado local
> (no depende del backend), badge real en el header y el CTA del
> detalle que hoy es un toast provisional. Checkout es §021,
> pedidos §022.

---

## Problema

El cliente ya puede personalizar un producto (§018/§019) pero no
puede guardarlo en ningún lado: el CTA "Agregar al carrito" del
detalle muestra `comingSoon`, el badge del icono del header es un
"2" fijo y la ruta `/cart` no existe. Falta toda la pieza "pedido
en construcción": entidad del ítem personalizado, estado global del
carrito, la pantalla y la conexión detalle → carrito → badge.

## Decisiones propuestas

1. **CartItem con snapshots + modificadores added/removed.** El
   ítem guarda productId/slug/nombre/precio base en el momento de
   agregar, y la personalización como filas `CartModifier` con
   `action: added|removed` y `priceDelta` — espejo 1:1 del contrato
   `order_item_modifiers` del backend (propuesta backend/015 ya no
   traduce nada). Un reemplazo gratis = fila `removed` del agotado +
   fila `added` del reemplazo con `priceDelta: 0`. El resumen de la
   fila lo compone la entidad (`sin X · +Y · Z`).
2. **CartCubit singleton en memoria** — misma posición que
   CatalogCubit (provider sobre el shell): una instancia sirve
   badge, pantalla y futuros call-sites. El carrito NO persiste al
   cerrar la app en el MVP (si el usuario lo pide, es pendiente).
   Id propio `cart-<n>` determinista para keys/tests.
3. **Merge por configuración idéntica**: mismo producto con la
   misma personalización suma cantidad en la misma fila; personali-
   zación distinta = fila aparte (la comparación es por conjunto de
   modificadores `optionId:action:priceDelta`, no por nombre).
4. **El carrito vive dentro del shell** (`/home/cart`, hijo de la
   rama home con la misma transición slideUp del detalle): header y
   nav bar se conservan — el usuario puede seguir sumando sin
   cambiar de contexto. La flecha vuelve al catálogo.
5. **Post-agregado: toast + volver a la carta.** El detalle se
   cierra tras agregar (feedback `AppToast.success`), porque el
   caso común es seguir pidiendo cosas distintas, no el mismo perro.
6. **Badge = total de unidades** (Σ quantity) — invisible en 0.
   Tap del icono del header navega a `AuthGuard.cartRoute`.
7. **Cantidad solo en el carrito** (stepper − / + por fila, − en 1
   elimina; swipe Dismissible también elimina). El detalle agrega
   de a uno — sin stepper ahí. Nota por ítem queda fuera: la nota
   va a nivel pedido en checkout (§021).
8. **"Ir a pagar" sigue provisional** (toast `comingSoon`) hasta
   §021 checkout — se muestra el footer completo con subtotal.
9. **Composición de pantalla = familia del detalle**:
   SignatureStrip + título naciente dentro del scroll + cards
   straddle por ítem + footer fijo subtotal/CTA + flecha back
   fija sobre la franja.

## Contratos de datos (lo que el ítem debe capturar)

`CartItem` refleja exactamente lo que el detalle puede producir:
quitados (removed, 0) · adicionales (added, precio real) ·
reemplazos gratis (removed agotado + added reemplazo, 0) ·
toppings/salsas (added, 0) · cantidad. Pan y salchicha fijos no
generan fila — nunca salen de `RemovableRow`.

## Archivos y código propuesto

### `lib/features/cart/domain/entities/cart_modifier.dart` — NUEVO

```dart
import 'package:equatable/equatable.dart';

/// Acción del modificador — espejo del enum del backend
/// (order_item_modifiers.action, propuesta 013): un ítem del
/// carrito se serializa 1:1 a filas added/removed sin traducir.
enum CartModifierAction { added, removed }

/// Una fila de personalización del ítem (§020). `optionId` es el id
/// real de modifier_options del backend; `optionName` y `priceDelta`
/// son SNAPSHOTS del momento de agregar — el nombre no cambia si la
/// carta se actualiza, y la revalidación de precios es server-side
/// al crear la orden (pendiente backend/009).
class CartModifier extends Equatable {
  const CartModifier({
    required this.optionId,
    required this.optionName,
    required this.action,
    required this.priceDelta,
  });

  final String optionId;
  final String optionName;
  final CartModifierAction action;

  /// Extra cobrado: precio real en adicionales; 0 en quitados,
  /// toppings, salsas y reemplazos gratis.
  final int priceDelta;

  @override
  List<Object?> get props => [optionId, optionName, action, priceDelta];
}
```

### `lib/features/cart/domain/entities/cart_item.dart` — NUEVO

```dart
import 'package:equatable/equatable.dart';

import 'cart_modifier.dart';

/// Ítem del carrito = producto + personalización completa + cantidad
/// (§020). Todo snapshot: el carrito no consulta la carta — si el
/// producto cambia de precio o desaparece, la orden se revalida en
/// el backend al crearla.
class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productSlug,
    required this.productName,
    required this.unitBase,
    required this.modifiers,
    this.imageUrl,
    this.quantity = 1,
  });

  /// Id local `cart-<n>` — key de lista y futuras ediciones.
  final String id;

  final String productId;
  final String productSlug;
  final String productName;

  /// Foto remota (null hoy — el tile usa el asset por slug).
  final String? imageUrl;

  /// basePrice snapshot.
  final int unitBase;

  /// Personalización como filas added/removed — mapea 1:1 a
  /// order_item_modifiers. Orden de composición: quitados,
  /// reemplazos (removed + added), adicionales, toppings, salsas.
  final List<CartModifier> modifiers;

  final int quantity;

  /// Precio unitario con adicionales — la fila muestra ESTE
  /// (lo que paga cada unidad), no el base.
  int get unitPrice =>
      unitBase +
      modifiers
          .where((m) => m.action == CartModifierAction.added)
          .fold(0, (s, m) => s + m.priceDelta);

  int get lineTotal => unitPrice * quantity;

  /// Mismo producto + MISMO conjunto de modificadores → al
  /// re-agregar suma cantidad, no duplica fila. La comparación es
  /// por clave `optionId:action:priceDelta` (orden irrelevante —
  /// los sets del detalle no garantizan orden de selección).
  bool sameConfiguration(CartItem other) {
    if (other.productId != productId ||
        other.modifiers.length != modifiers.length) {
      return false;
    }
    String key(CartModifier m) =>
        '${m.optionId}:${m.action.name}:${m.priceDelta}';
    final a = {for (final m in modifiers) key(m)};
    final b = {for (final m in other.modifiers) key(m)};
    return a.length == b.length && a.containsAll(b);
  }

  /// Resumen legible de la fila: removed → "sin X", added con
  /// precio → "+X", added gratis → "X". Vacío si el perro va tal
  /// cual de la carta.
  String get modifiersSummary {
    if (modifiers.isEmpty) return '';
    return modifiers
        .map(
          (m) => switch (m.action) {
            CartModifierAction.removed => 'sin ${m.optionName}',
            CartModifierAction.added =>
              m.priceDelta > 0 ? '+${m.optionName}' : m.optionName,
          },
        )
        .join(' · ');
  }

  CartItem copyWith({String? id, int? quantity}) => CartItem(
    id: id ?? this.id,
    productId: productId,
    productSlug: productSlug,
    productName: productName,
    imageUrl: imageUrl,
    unitBase: unitBase,
    modifiers: modifiers,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [
    id,
    productId,
    productSlug,
    productName,
    imageUrl,
    unitBase,
    modifiers,
    quantity,
  ];
}
```

### `lib/features/cart/presentation/cubit/cart_state.dart` — NUEVO

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';

/// Estado del carrito (§020): solo ítems — sin status/failures
/// porque hoy es 100% local (no hay carga remota que pueda fallar).
class CartState extends Equatable {
  const CartState({this.items = const <CartItem>[]});

  final List<CartItem> items;

  /// Unidades totales — el badge del header (Σ quantity).
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// Subtotal del pedido en construcción.
  int get subtotal => items.fold(0, (s, i) => s + i.lineTotal);

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}
```

### `lib/features/cart/presentation/cubit/cart_cubit.dart` — NUEVO

```dart
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

  void removeItem(String itemId) => emit(
    CartState(items: state.items.where((i) => i.id != itemId).toList()),
  );

  /// Vacía el carrito — checkout exitoso (§021) y un futuro
  /// "vaciar" manual lo usan.
  void clear() => emit(const CartState());
}
```

### `lib/features/cart/presentation/widgets/quantity_stepper.dart` — NUEVO

```dart
import 'package:flutter/material.dart';

/// Stepper − n + de la fila del carrito (§020). Botones 28px —
/// compacto pero con tap real (IconButton shrinkWrap). El caller
/// decide qué pasa al llegar a 0 (cart elimina la fila).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onChanged,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget button(IconData icon, int delta) => SizedBox(
      height: 28,
      width: 28,
      child: IconButton(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onChanged(quantity + delta),
        icon: Icon(icon, size: 18, color: colors.primary),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -1),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          button(Icons.add_rounded, 1),
        ],
      ),
    );
  }
}
```

### `lib/features/cart/presentation/widgets/cart_item_tile.dart` — NUEVO

```dart
import 'package:flutter/material.dart';

import '../../../home/presentation/utils/catalog_assets.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/product_image.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/cart_item.dart';
import 'quantity_stepper.dart';

/// Fila del carrito (§020): card straddle de la familia (misma
/// geometría que CustomizationSection — nace a la derecha de la
/// franja). Imagen por slug + nombre + resumen de personalización +
/// precio unitario; debajo, stepper y total de línea.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    super.key,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final strip = c.maxWidth * kSignatureStripFraction;
          return Padding(
            padding: EdgeInsets.only(
              left: strip * kCardStripInset,
              right: blackZoneMargin(c.maxWidth),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: colors.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductImage(
                          asset: CatalogAssets.productAsset(
                            item.productSlug,
                          ),
                          imageUrl: item.imageUrl,
                          size: 52,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (item.modifiersSummary.isNotEmpty)
                                Text(
                                  item.modifiersSummary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatCop(item.unitPrice),
                          style: text.bodyMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        QuantityStepper(
                          quantity: item.quantity,
                          onChanged: onQuantityChanged,
                        ),
                        const Spacer(),
                        Text(
                          formatCop(item.lineTotal),
                          style: text.titleSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### `lib/features/cart/presentation/widgets/cart_empty_view.dart` — NUEVO

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Carrito vacío (§020): ícono + título + CTA al menú — misma
/// composición que CatalogErrorView.
class CartEmptyView extends StatelessWidget {
  const CartEmptyView({required this.onBrowse, super.key});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.cartEmptyTitle,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cartEmptySubtitle,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onBrowse,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: Text(l10n.cartEmptyCta),
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/features/cart/presentation/screens/cart_screen.dart` — NUEVO

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import '../widgets/cart_empty_view.dart';
import '../widgets/cart_item_tile.dart';

/// Carrito (§020): familia del detalle — franja firma + título
/// naciente dentro del scroll + cards straddle por ítem + footer
/// fijo. Vive DENTRO del shell (/home/cart): header y nav bar se
/// conservan. Cada fila es Dismissible (swipe elimina) y el − del
/// stepper en 1 también.
///
/// El CTA "Ir a pagar" sigue provisional (toast) hasta §021
/// checkout — el footer ya muestra el subtotal real.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              const SignatureStrip(fraction: kSignatureStripFraction),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: state.isEmpty
                        ? ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _CartTitle(),
                              const SizedBox(height: 120),
                              CartEmptyView(
                                onBrowse: () =>
                                    context.go(AuthGuard.homeRoute),
                              ),
                            ],
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _CartTitle(),
                              for (final item in state.items)
                                Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => context
                                      .read<CartCubit>()
                                      .removeItem(item.id),
                                  background: Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 24,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                  child: CartItemTile(
                                    item: item,
                                    onQuantityChanged: (q) => context
                                        .read<CartCubit>()
                                        .updateQuantity(item.id, q),
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                  // Footer fijo — mismo patrón del detalle: fondo
                  // opaco para que la franja no se filtre.
                  if (!state.isEmpty)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            12,
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.cartSubtotalLabel,
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatCop(state.subtotal),
                                    style: text.titleMedium?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  // PROVISIONAL hasta §021 checkout.
                                  onPressed: () => AppToast.info(
                                    context,
                                    l10n.comingSoon,
                                  ),
                                  child: Text(l10n.cartCheckoutCta),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                top: 12,
                left: 4,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.onPrimary,
                  ),
                  tooltip: l10n.catalogBackTooltip,
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Título "Tu carrito" naciendo de la franja — mismo motivo del
/// detalle (decisión del usuario, dentro del scroll).
class _CartTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.cartTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### `lib/core/routes/auth_guard.dart` — EDITAR

```dart
  static const String ordersRoute = '/orders';
  static const String profileRoute = '/profile';
  // Carrito — hijo de la rama home (dentro del shell, §020).
  static const String cartRoute = '/home/cart';
```

### `lib/core/routes/app_router.dart` — EDITAR

```dart
// imports:
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
```

```dart
// builder del shell — MultiBlocProvider: CatalogCubit (menú) +
// CartCubit (carrito compartido, §020):
builder: (context, state, navigationShell) => MultiBlocProvider(
  providers: [
    BlocProvider.value(value: locator<CatalogCubit>()..load()),
    BlocProvider.value(value: locator<CartCubit>()),
  ],
  child: AppShellLayout(shell: navigationShell),
),
```

```dart
// Hijo de homeRoute (hermano de category/:categorySlug):
GoRoute(
  path: 'cart',
  pageBuilder: (context, state) =>
      CustomTransitions.slideUp(state, const CartScreen()),
),
```

### `lib/core/layout/shell_header.dart` — EDITAR

```dart
// imports: flutter_bloc, go_router, cart_cubit, auth_guard
// (app_toast sigue — notifications la usa)
```

```dart
// Dentro del Row de acciones del header (reemplaza el bloque del
// iconButton de carrito con badge fijo "2" + toast):
_buildCartButton(context, l10n, colors),
```

```dart
/// Carrito: navega a /home/cart (§020). Badge = unidades reales
/// del CartCubit — invisible en 0.
Widget _buildCartButton(
  BuildContext context,
  AppLocalizations l10n,
  ColorScheme colors,
) {
  final count = context.select((CartCubit c) => c.state.itemCount);
  return IconButton(
    tooltip: l10n.shellCartTooltip,
    onPressed: () => context.go(AuthGuard.cartRoute),
    icon: Badge(
      isLabelVisible: count > 0,
      label: Text(
        '$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      backgroundColor: colors.primary,
      textColor: colors.onPrimary,
      child: Icon(Icons.shopping_cart_outlined, color: colors.onSurface),
    ),
  );
}
```

### `lib/features/home/presentation/screens/product_detail_screen.dart` — EDITAR

```dart
// imports:
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/domain/entities/cart_modifier.dart';
```

```dart
// En _ProductDetailScreenState — el CTA deja de ser toast y arma
// el CartItem con la personalización actual (§020).

/// Resuelve una opción por id dentro de los grupos del producto —
/// para los snapshots de nombre/precio del CartModifier.
ModifierOption? _optionById(CatalogProduct item, String id) {
  for (final g in item.modifierGroups) {
    for (final o in g.options) {
      if (o.id == id) return o;
    }
  }
  return null;
}

/// Traduce las selecciones locales a filas CartModifier — el
/// reemplazo gratis produce DOS filas (removed del agotado +
/// added del reemplazo a 0), como en order_item_modifiers.
List<CartModifier> _buildModifiers(CatalogProduct item) {
  CartModifier? mod(String id, CartModifierAction a, [int price = 0]) {
    final o = _optionById(item, id);
    if (o == null) return null;
    return CartModifier(
      optionId: o.id,
      optionName: o.name,
      action: a,
      priceDelta: price,
    );
  }

  return [
    for (final id in _removed)
      if (mod(id, CartModifierAction.removed) case final m?) m,
    for (final e in _replacements.entries) ...[
      if (mod(e.key, CartModifierAction.removed) case final m?) m,
      if (mod(e.value, CartModifierAction.added) case final m?) m,
    ],
    for (final id in _extras)
      if (mod(
            id,
            CartModifierAction.added,
            _optionById(item, id)?.extraPrice ?? 0,
          )
          case final m?)
        m,
    for (final id in _toppings)
      if (mod(id, CartModifierAction.added) case final m?) m,
    for (final id in _sauces)
      if (mod(id, CartModifierAction.added) case final m?) m,
  ];
}

void _addToCart(CatalogProduct item) {
  context.read<CartCubit>().addItem(
    productId: item.id,
    productSlug: item.slug,
    productName: item.name,
    imageUrl: item.imageUrl,
    unitBase: item.basePrice,
    modifiers: _buildModifiers(item),
  );
  AppToast.success(context, l10n.cartItemAdded);
  context.pop();
}
```

```dart
// CTA sellable — reemplaza el onPressed del toast:
FilledButton(
  onPressed: () => _addToCart(item),
  child: Text(l10n.detailAddToCart),
)
```

### `lib/core/di/setup_di.dart` — EDITAR

```dart
// --- Carrito (propuesta 020): lazySingleton — estado compartido
// entre badge, pantalla y checkout futuro; una sola instancia.
// En memoria: no persiste entre arranques (decisión MVP).
locator.registerLazySingleton<CartCubit>(() => CartCubit());
```

### `lib/l10n/app_es.arb` — AGREGAR

```json
  "cartTitle": "Tu carrito",
  "@cartTitle": {
    "description": "Título de la pantalla del carrito"
  },
  "cartEmptyTitle": "Tu carrito está vacío",
  "@cartEmptyTitle": {
    "description": "Título del estado vacío del carrito"
  },
  "cartEmptySubtitle": "Suma algo rico del menú",
  "@cartEmptySubtitle": {
    "description": "Subtítulo del estado vacío del carrito"
  },
  "cartEmptyCta": "Ver el menú",
  "@cartEmptyCta": {
    "description": "Botón del estado vacío que lleva al menú"
  },
  "cartSubtotalLabel": "Subtotal",
  "@cartSubtotalLabel": {
    "description": "Etiqueta del subtotal en el footer del carrito"
  },
  "cartCheckoutCta": "Ir a pagar",
  "@cartCheckoutCta": {
    "description": "Botón del footer del carrito — provisional hasta checkout (§021)"
  },
  "cartItemAdded": "Agregado al carrito",
  "@cartItemAdded": {
    "description": "Toast de confirmación tras agregar desde el detalle"
  }
```

### `test/features/cart/domain/entities/cart_item_test.dart` — NUEVO

- `sameConfiguration`: mismo producto + mismo conjunto en orden
  distinto → true; modificador distinto → false; otro producto →
  false.
- `unitPrice`/`lineTotal`: base + extras × qty.
- `modifiersSummary`: formatos `sin X`/`+X`/`X` y vacío.

### `test/features/cart/presentation/cubit/cart_cubit_test.dart` — NUEVO

- `addItem` primera vez → 1 ítem qty 1 con id `cart-1`.
- `addItem` misma configuración → qty 2, una sola fila.
- `addItem` configuración distinta → 2 filas.
- `updateQuantity` a 3 → qty 3 y subtotal recalculado; a 0 → elimina.
- `removeItem` / `clear`.
- Getters del state: `itemCount` suma unidades, `subtotal`.

### `test/features/cart/presentation/screens/cart_screen_test.dart` — NUEVO

Harness: MaterialApp + AppLocalizations + `BlocProvider<CartCubit>`
con un cubit real pre-poblado (más simple que mockear — métodos
síncronos).

- Vacío → `cartEmptyTitle` + CTA visible; sin footer.
- Con 2 ítems → nombres, resúmenes de personalización y subtotal.
- Tap en `+` del stepper → cantidad y total crecen.
- `−` en qty 1 → la fila desaparece.
- Swipe (Dismissible) → la fila desaparece.
- CTA → existe (no se verifica el toast provisional).

### `test/features/home/presentation/product_detail_screen_test.dart` — EDITAR

- El harness agrega `BlocProvider<CartCubit>` (real) junto al mock
  de CatalogCubit.
- Caso "Agregar al carrito": tap → verifica ítem en el cubit con los
  modificadores esperados (un quitado + un extra del fixture) — el
  pop no se verifica por GoRouter (la screen usa context.pop, el
  test monta sin router: revisar si pop sobre Navigator simple
  funciona en el harness actual; si no, envolver en Navigator y
  asertar la ruta desapilada o al menos el efecto en el cubit).

### `Design/design-system.yaml` — EDITAR

- Nueva spec `screens.cart`: composición franja+título naciente,
  tile de ítem (img 52 + nombre + resumen + unit price, stepper +
  line total), footer subtotal/CTA, empty con CTA al menú,
  Dismissible endToStart.
- Bump de versión + changelog entrada `020-cart-presentacion`.

## Verificación

1. `flutter gen-l10n` → generated sin errores
2. `dart format .` + `flutter analyze` → limpio
3. `flutter test` → verde (incluye los tests del detalle ajustados)
4. Emulador (tú validas):
   - Agregar El Depredador personalizado (quitas + extras + toppings)
     → toast + volver a la carta
   - Badge del header con unidades reales
   - Carrito: filas con resumen `sin X · +Y`, stepper, swipe borra,
     subtotal correcto
   - Vacío: empty state + "Ver el menú"
5. Revisiones estética + UI antes de mostrarte el resultado

## Pendientes que deja (intencionales)

- **Checkout** (§021): servicio pickup/domicilio, dirección, Nequi,
  nota del pedido, "Ir a pagar" deja de ser provisional.
- **Pedidos** (§022): tab activo/historial/detalle.
- **Persistencia del carrito**: fuera del MVP — si la quieres, se
  archiva en pendientes/.
- El pill "Abierto/Cerrado" del header con `GET /store/config` real.
- Pendiente 010 (extracción de widgets del detalle): el título
  naciente se duplica una vez más acá — entra en esa limpieza.
