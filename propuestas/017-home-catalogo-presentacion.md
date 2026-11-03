# Propuesta: Home — selector de categorías + lista por categoría (presentación)

Primera pantalla real del área autenticada: reemplaza el placeholder de
la branch `/home` del shell (§016). **Fase presentación** (screen-first):
sin domain/data — el catálogo es un mock estático con la carta real que
definió el usuario; acciones (agregar, ver promo) son provisionales →
`AppToast.info('Disponible próximamente')`.

**v2 — referencia visual del usuario**: el home es un **selector de
categorías** estilo food-app (franja vertical + cards desplazadas con la
imagen del producto sobresaliendo por la izquierda), no un listado con
chips. Adaptado a nuestra paleta oscura (la referencia era clara) y sin
sus fuentes.

## Decisiones del usuario (ya tomadas)

- **Referencia aplicada**: franja vertical izquierda + cards de categoría
  desplazadas con imagen de producto sobresaliente + nombre + conteo +
  chevron. Colores/fuentes de la referencia NO se toman — va la paleta
  propia (visual-reference-review: tabla queda/cambia/rechaza aprobada).
- **Franja: mostaza sólida** (`colorScheme.primary`).
- **Navegación: categorías → lista hija** — home = selector; el tap abre
  `/home/category/{id}` (push dentro del branch `/home`).
- **Hero El Depredador: solo dentro de Perros** — el home queda limpio
  (estado del local + banner promo + las 4 categorías).
- **Fotos SIN FONDO**: fuentes Pexels recortadas con rembg local (modelo
  bria-rmbg) + crop al bbox del alpha → PNG transparente; SIN manos
  (decisión del usuario: solo el producto). PROVISIONALES hasta fotografía
  real (pendiente de producción).
- Toppings/salsas/adiciones NO aparecen — son el configurador del perro
  (siguiente propuesta). Tap en card de producto o "+" → toast
  provisional.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | +`assets/images/products/` en `assets:` |
| `assets/images/products/*.png` | 9 PNG sin fondo ya procesados (6 perros + papas + cat_bebidas + cat_combos) |
| `lib/l10n/app_es.arb` | +10 claves → `flutter gen-l10n` |
| `lib/features/home/presentation/data/catalog_mock.dart` | nuevo — categorías + metadatos, modelo, carta, `formatCop` |
| `lib/features/home/presentation/widgets/store_status_strip.dart` | nuevo |
| `lib/features/home/presentation/widgets/promo_banner.dart` | nuevo |
| `lib/features/home/presentation/widgets/category_card.dart` | nuevo — card desplazada con imagen sobresaliente |
| `lib/features/home/presentation/widgets/product_card.dart` | nuevo — card con producto flotando a la izquierda |
| `lib/features/home/presentation/widgets/hero_product_card.dart` | nuevo — destacado dentro de Perros |
| `lib/features/home/presentation/screens/home_screen.dart` | nuevo — franja mostaza + selector de categorías |
| `lib/features/home/presentation/screens/category_products_screen.dart` | nuevo — lista de productos de una categoría |
| `lib/core/routes/app_router.dart` | branch `/home` → `HomeScreen` + hija `category/:categoryId` |
| `test/features/home/presentation/home_screen_test.dart` | nuevo |
| `test/features/home/presentation/category_products_screen_test.dart` | nuevo |

## 1. l10n — claves nuevas en `app_es.arb`

```json
  "homeStoreOpen": "Abierto",
  "homeStoreClosed": "Cerrado",
  "homeStoreEta": "Tu pedido llega en 30-45 min",
  "homePromoTag": "PROMO",
  "homePromoTitle": "2×1 en El Cachorro — solo hoy",
  "homeFeaturedTag": "EL DE LA CASA",
  "catalogCategoryDogs": "Perros",
  "catalogCategoryMore": "& Más",
  "catalogCategoryDrinks": "Bebidas",
  "catalogCategoryCombos": "Combos",
  "catalogAddTooltip": "Agregar",
  "catalogProductsCount": "{count, plural, =1{1 producto} other{{count} productos}}",
  "@catalogProductsCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
```

Tras agregarlas: `flutter gen-l10n`.

## 2. `catalog_mock.dart` (nuevo)

```dart
/// Catálogo PROVISIONAL de la fase presentación (§017): la carta real
/// definida por el usuario (menú Depredadog — precios COP
/// provisionales). En integración viene de GET /catalog/* y este
/// archivo se elimina. Los textos de producto son DATA del negocio,
/// no chrome de UI — quedan en español como en la carta.
enum CatalogCategory { dogs, more, drinks, combos }

/// Metadatos de presentación por categoría: segmento de ruta e imagen
/// representativa (PNG sin fondo).
extension CatalogCategoryX on CatalogCategory {
  /// Segmento de ruta hija: /home/category/{segment}.
  String get segment => switch (this) {
    CatalogCategory.dogs => 'perros',
    CatalogCategory.more => 'mas',
    CatalogCategory.drinks => 'bebidas',
    CatalogCategory.combos => 'combos',
  };

  /// Imagen representativa en la card de categoría del home.
  String get coverAsset => switch (this) {
    CatalogCategory.dogs => 'assets/images/products/perro_depredador.png',
    CatalogCategory.more => 'assets/images/products/manada_papas.png',
    CatalogCategory.drinks => 'assets/images/products/cat_bebidas.png',
    CatalogCategory.combos => 'assets/images/products/cat_combos.png',
  };

  static CatalogCategory fromSegment(String segment) => switch (segment) {
    'mas' => CatalogCategory.more,
    'bebidas' => CatalogCategory.drinks,
    'combos' => CatalogCategory.combos,
    _ => CatalogCategory.dogs,
  };
}

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.ingredients,
    required this.priceCop,
    required this.imageAsset,
    required this.category,
  });

  final String id;
  final String name;
  final String tagline;
  final String ingredients;
  final int priceCop;
  final String imageAsset;
  final CatalogCategory category;
}

/// 14000 → "$14.000" (formato COP con separador de miles por punto).
String formatCop(int price) {
  final s = price.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}

/// Carta del menú — perros + & Más. Bebidas y Combos aún sin productos.
const depredadorItem = CatalogItem(
  id: 'depredador',
  name: 'El Depredador',
  tagline: 'El alfa come de todo.',
  ingredients:
      'Salchicha americana, carne desmechada, chile con carne, tocineta '
      'crocante, piña en trozos, maíz dulce, mozzarella y huevo de codorniz.',
  priceCop: 25000,
  imageAsset: 'assets/images/products/perro_depredador.png',
  category: CatalogCategory.dogs,
);

const catalogMockItems = <CatalogItem>[
  CatalogItem(
    id: 'cachorro',
    name: 'El Cachorro',
    tagline: 'El primer mordisco de la manada.',
    ingredients:
        'Salchicha americana, queso mozzarella fundido y huevo de codorniz.',
    priceCop: 14000,
    imageAsset: 'assets/images/products/perro_cachorro.png',
    category: CatalogCategory.dogs,
  ),
  CatalogItem(
    id: 'trampa',
    name: 'La Trampa',
    tagline: 'Lo dulce es el anzuelo.',
    ingredients:
        'Salchicha americana, mozzarella, piña en trozos y tocineta crocante.',
    priceCop: 16000,
    imageAsset: 'assets/images/products/perro_trampa.png',
    category: CatalogCategory.dogs,
  ),
  CatalogItem(
    id: 'ave_presa',
    name: 'Ave de Presa',
    tagline: 'Cayó directo del corral.',
    ingredients:
        'Salchicha americana, pollo desmechado, maíz dulce, mozzarella '
        'y huevo de codorniz.',
    priceCop: 18000,
    imageAsset: 'assets/images/products/perro_ave_presa.png',
    category: CatalogCategory.dogs,
  ),
  CatalogItem(
    id: 'coyote',
    name: 'El Coyote',
    tagline: 'Cacería del desierto.',
    ingredients:
        'Salchicha americana, chile con carne, salsa de queso cheddar '
        'y maíz dulce.',
    priceCop: 18000,
    imageAsset: 'assets/images/products/perro_coyote.png',
    category: CatalogCategory.dogs,
  ),
  CatalogItem(
    id: 'carnicero',
    name: 'El Carnicero',
    tagline: 'Carne sobre carne, sin piedad.',
    ingredients:
        'Salchicha americana, salami, tocineta crocante y queso mozzarella.',
    priceCop: 17000,
    imageAsset: 'assets/images/products/perro_carnicero.png',
    category: CatalogCategory.dogs,
  ),
  depredadorItem,
  CatalogItem(
    id: 'manada_papas',
    name: 'Manada de Papas',
    tagline: 'Con las salsas de la casa.',
    ingredients: 'Papas a la francesa.',
    priceCop: 10000,
    imageAsset: 'assets/images/products/manada_papas.png',
    category: CatalogCategory.more,
  ),
];

/// Conteo de productos por categoría (para la card del home).
int catalogCountOf(CatalogCategory c) =>
    catalogMockItems.where((i) => i.category == c).length;
```

## 3. `store_status_strip.dart` (nuevo)

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Franja fina de estado del local (PROVISIONAL §017 — isOpen mock).
/// En integración la alimenta el módulo store (horario real + ETA).
class StoreStatusStrip extends StatelessWidget {
  const StoreStatusStrip({required this.isOpen, super.key});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? colors.tertiary : colors.error,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOpen ? l10n.homeStoreOpen : l10n.homeStoreClosed,
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (isOpen) ...[
            Text('  ·  ', style: text.labelLarge),
            Text(
              l10n.homeStoreEta,
              style: text.labelLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

## 4. `promo_banner.dart` (nuevo)

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_toast.dart';

/// Banner de promoción del día (PROVISIONAL §017 — copy mock; el módulo
/// promotions alimenta contenido y destino reales).
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homePromoTag,
                    style: text.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.homePromoTitle, style: text.titleSmall),
                ],
              ),
            ),
            IconButton(
              onPressed: () => AppToast.info(context, l10n.comingSoon),
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 5. `category_card.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/routes/auth_guard.dart';
import '../data/catalog_mock.dart';

/// Card de categoría del selector del home (§017, referencia del
/// usuario): la card va DESPLAZADA — su borde izquierdo empieza ~72px
/// adentro y la imagen del producto sobresale FLOTANDO sobre la franja
/// mostaza (PNG sin fondo → sin máscara circular). Nombre + conteo
/// honesto ("N productos" o "Disponible próximamente" en vacías) +
/// chevron. Navega con push a /home/category/{segment}.
class CategoryCard extends StatelessWidget {
  const CategoryCard({required this.category, super.key});

  final CatalogCategory category;

  String _label(AppLocalizations l10n) => switch (category) {
    CatalogCategory.dogs => l10n.catalogCategoryDogs,
    CatalogCategory.more => l10n.catalogCategoryMore,
    CatalogCategory.drinks => l10n.catalogCategoryDrinks,
    CatalogCategory.combos => l10n.catalogCategoryCombos,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = catalogCountOf(category);
    return SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Card desplazada — empieza 72px adentro para dejar el hueco
          // de la imagen sobresaliente.
          Positioned.fill(
            left: 72,
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: colors.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () => context.push(
                  '${AuthGuard.homeRoute}/category/${category.segment}',
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 48, right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(l10n),
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              count > 0
                                  ? l10n.catalogProductsCount(count)
                                  : l10n.comingSoon,
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Imagen del producto sobresaliente — flota sobre la franja
          // y el borde de la card (el PNG no necesita círculo).
          Positioned(
            left: 8,
            child: IgnorePointer(
              child: Image.asset(
                category.coverAsset,
                width: 84,
                height: 84,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 6. `product_card.dart` (nuevo)

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/catalog_mock.dart';

/// Card de producto de la lista por categoría (§017) — misma firma del
/// selector: producto PNG flotando sobre el borde izquierdo de la card.
/// Tap y "+" PROVISIONALES — el configurador llega después.
class ProductCard extends StatelessWidget {
  const ProductCard({required this.item, super.key});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 116,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            left: 56,
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: colors.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () => AppToast.info(context, l10n.comingSoon),
                child: Padding(
                  padding: const EdgeInsets.only(left: 52, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: colors.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatCop(item.priceCop),
                              style: text.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: colors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => AppToast.info(context, l10n.comingSoon),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: colors.onPrimary,
                              semanticLabel: l10n.catalogAddTooltip,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            child: IgnorePointer(
              child: Image.asset(
                item.imageAsset,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 7. `hero_product_card.dart` (nuevo)

```dart
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/catalog_mock.dart';

/// Card hero del producto insignia (§017 — dentro de la lista Perros,
/// decisión del usuario). Misma firma que las demás cards pero más alta
/// y con tag "EL DE LA CASA" + CTA provisional.
class HeroProductCard extends StatelessWidget {
  const HeroProductCard({required this.item, super.key});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            left: 72,
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: colors.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () => AppToast.info(context, l10n.comingSoon),
                child: Padding(
                  padding: const EdgeInsets.only(left: 56, right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeFeaturedTag,
                        style: text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        item.tagline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            formatCop(item.priceCop),
                            style: text.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () =>
                                AppToast.info(context, l10n.comingSoon),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(l10n.catalogAddTooltip),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 4,
            child: IgnorePointer(
              child: Image.asset(
                item.imageAsset,
                width: 120,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 8. `home_screen.dart` (nuevo)

```dart
import 'package:flutter/material.dart';

import '../data/catalog_mock.dart';
import '../widgets/category_card.dart';
import '../widgets/promo_banner.dart';
import '../widgets/store_status_strip.dart';

/// Home — selector de categorías (§017, fase presentación). Firma de la
/// referencia del usuario: franja vertical MOSTAZA sólida a la izquierda
/// anclando las imágenes sobresalientes de las cards de categoría.
/// Estado del local + promo van dentro de la columna desplazada.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Ancho de la franja firma — cubre también el área de las imágenes
  /// sobresalientes de las cards (su Positioned left arranca en 8px).
  static const double _stripWidth = 72;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          // Franja firma — mostaza sólida (decisión del usuario). El
          // contenido scrollea ENCIMA; las imágenes de las cards caen
          // sobre ella.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _stripWidth,
            child: ColoredBox(color: colors.primary),
          ),
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: const [
              // PROVISIONAL: isOpen mock — el módulo store lo alimenta.
              StoreStatusStrip(isOpen: true),
              PromoBanner(),
              SizedBox(height: 8),
              CategoryCard(category: CatalogCategory.dogs),
              CategoryCard(category: CatalogCategory.more),
              CategoryCard(category: CatalogCategory.drinks),
              CategoryCard(category: CatalogCategory.combos),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 9. `category_products_screen.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import '../widgets/hero_product_card.dart';
import '../widgets/product_card.dart';

/// Lista de productos de una categoría (§017 — hija de /home por push).
/// Franja fina mostaza (continuidad de la firma del home) + flecha de
/// regreso + nombre de la categoría + cards con producto sobresaliente.
/// El Depredador encabeza Perros como hero (decisión del usuario).
class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({required this.category, super.key});

  final CatalogCategory category;

  String _label(AppLocalizations l10n) => switch (category) {
    CatalogCategory.dogs => l10n.catalogCategoryDogs,
    CatalogCategory.more => l10n.catalogCategoryMore,
    CatalogCategory.drinks => l10n.catalogCategoryDrinks,
    CatalogCategory.combos => l10n.catalogCategoryCombos,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items =
        catalogMockItems.where((i) => i.category == category).toList();
    return Scaffold(
      body: Stack(
        children: [
          // Franja fina — continuidad de la firma del selector.
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 40,
            child: ColoredBox(color: Color(0xFFFDD019)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _label(l10n),
                      style: text.headlineSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (category == CatalogCategory.dogs)
                      const HeroProductCard(item: depredadorItem),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            l10n.comingSoon,
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final item in items)
                        if (item != depredadorItem ||
                            category != CatalogCategory.dogs)
                          ProductCard(item: item),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

> Ojo: el hero muestra El Depredador destacado y NO se repite como card
> normal (solo-hero, misma semántica que "duplicado" no aplica — el hero
> reemplaza su posición en la lista; si se quiere duplicado se quita el
> filtro `item != depredadorItem`).

## 10. `app_router.dart` (modificación)

```dart
import '../../features/home/presentation/screens/category_products_screen.dart'; // NUEVO
import '../../features/home/presentation/screens/home_screen.dart'; // NUEVO
import '../../features/home/presentation/data/catalog_mock.dart'; // NUEVO
```

Branch `/home` con su hija de categoría (segmento RELATIVO — la regla):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.homeRoute,
                pageBuilder: (context, state) =>
                    CustomTransitions.fade(state, const HomeScreen()),
                routes: [
                  GoRoute(
                    path: 'category/:categoryId',
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(
                      state,
                      CategoryProductsScreen(
                        category: CatalogCategoryX.fromSegment(
                          state.pathParameters['categoryId'] ?? '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
```

Las cards navegan con `context.push('/home/category/{segment}')` —
detalle del mismo branch (push, no go, para conservar el stack).

## 11. `pubspec.yaml` (modificación)

```yaml
  assets:
    - assets/images/
    - assets/images/products/
```

## 12. Tests

### `home_screen_test.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:depredadog_app/features/home/presentation/screens/home_screen.dart';
import 'package:depredadog_app/features/home/presentation/data/catalog_mock.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'category/:categoryId',
              builder: (context, state) => CategoryProductsScreen(
                category: CatalogCategoryX.fromSegment(
                  state.pathParameters['categoryId'] ?? '',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: buildRouter(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
      ),
    );
  }

  testWidgets('renderiza estado del local, promo y las 4 categorías', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Abierto'), findsOneWidget);
    expect(find.text('Tu pedido llega en 30-45 min'), findsOneWidget);
    expect(find.text('PROMO'), findsOneWidget);
    expect(find.text('Perros'), findsOneWidget);
    expect(find.text('& Más'), findsOneWidget);
    expect(find.text('Bebidas'), findsOneWidget);
    expect(find.text('Combos'), findsOneWidget);
    expect(find.text('6 productos'), findsOneWidget);
    expect(find.text('1 producto'), findsOneWidget);
    expect(find.text('Disponible próximamente'), findsNWidgets(2));
  });

  testWidgets('tap en Perros navega a la lista con hero y productos', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perros'));
    await tester.pumpAndSettle();

    expect(find.text('EL DE LA CASA'), findsOneWidget);
    expect(find.text('El Depredador'), findsOneWidget);
    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text(r'$25.000'), findsOneWidget);
    expect(find.text(r'$14.000'), findsOneWidget);
    // El Depredador NO se repite como card normal (solo hero).
    expect(find.text('El Depredador'), findsOneWidget);
  });
}
```

### `category_products_screen_test.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/presentation/data/catalog_mock.dart';
import 'package:depredadog_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  Future<void> pumpList(WidgetTester tester, CatalogCategory c) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CategoryProductsScreen(category: c),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
      ),
    );
  }

  testWidgets('categoría vacía muestra Disponible próximamente', (
    tester,
  ) async {
    await pumpList(tester, CatalogCategory.combos);
    await tester.pumpAndSettle();

    expect(find.text('Combos'), findsOneWidget);
    expect(find.text('Disponible próximamente'), findsOneWidget);
  });

  testWidgets('agregar dispara toast provisional', (tester) async {
    const channel = MethodChannel('PonnamKarthik/fluttertoast');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await pumpList(tester, CatalogCategory.more);
    await tester.pumpAndSettle();
    expect(find.text('Manada de Papas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.first.arguments['msg'], 'Disponible próximamente');

    await tester.pump(const Duration(seconds: 2));
  });
}
```

## Verificación

1. `flutter gen-l10n` → regenera localizaciones.
2. `flutter analyze` → 0 issues.
3. `flutter test` → suite completa en verde.
4. Build + install debug APK → revisión visual: franja mostaza, cards
   desplazadas, imágenes flotando, navegación Perros→lista, back.
   **Ojo**: verificar que el back nativo en la lista haga pop al home y
   NO salga de la app — el PopScope del shell (canPop en index 0) podría
   interferir con el pop interno del branch; si sale en vez de volver,
   ajustar (canPop solo cuando el branch está en su raíz).
5. revisor-ui → correcciones → aprobación visual del usuario.
6. `Design/design-system.yaml` bump minor con spec home + patrón de
   "franja firma" (reusable en otras secciones).
7. Commit.

## Pendientes que quedan registrados (no de esta propuesta)

- Fotos reales del producto (reemplazar stock Pexels recortado).
- Configurador de perro (toppings/salsas/adiciones) — siguiente
  propuesta de presentación (hija de `/home`).
- Estado real del local y banner real — módulos store/promotions.
- Productos de Bebidas y Combos — aún no están en la carta.
