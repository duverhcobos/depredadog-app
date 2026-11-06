import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/cart/presentation/widgets/cart_item_detail_panel.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: child),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('es'),
);

void main() {
  testWidgets('secciones por grupo: Ingredientes/Se le quitó/Adicionales/'
      'Toppings/Salsas con bullets', (tester) async {
    const item = CartItem(
      id: 'cart-1',
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      includedNames: ['Pan artesanal', 'Salchicha americana'],
      modifiers: [
        CartModifier(
          optionId: 'o-huevo',
          optionName: 'Huevo de codorniz',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
        CartModifier(
          optionId: 'o-salami',
          optionName: 'Salami',
          action: CartModifierAction.added,
          priceDelta: 4000,
          group: CartModifierGroup.extra,
        ),
        CartModifier(
          optionId: 'o-tostacos',
          optionName: 'Tostacos',
          action: CartModifierAction.added,
          priceDelta: 0,
          group: CartModifierGroup.topping,
        ),
        CartModifier(
          optionId: 'o-depredador',
          optionName: 'Salsa Depredador',
          action: CartModifierAction.added,
          priceDelta: 0,
          group: CartModifierGroup.sauce,
        ),
      ],
    );

    await tester.pumpWidget(_host(const CartItemDetailPanel(item: item)));

    // Encabezados de sección en Anton mostaza (decisión §021b).
    expect(find.text('Ingredientes'), findsOneWidget);
    expect(find.text('Se le quitó'), findsOneWidget);
    expect(find.text('Adicionales'), findsOneWidget);
    expect(find.text('Toppings'), findsOneWidget);
    expect(find.text('Salsas'), findsOneWidget);

    // Ítems con su bullet — cada nombre en su propia fila.
    expect(find.text('Pan artesanal'), findsOneWidget);
    expect(find.text('Salchicha americana'), findsOneWidget);
    expect(find.text('Huevo de codorniz'), findsOneWidget);
    expect(find.text('Tostacos'), findsOneWidget);
    expect(find.text('Salsa Depredador'), findsOneWidget);
    expect(find.text(r'Salami +$4.000', findRichText: true), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets('added sin group cae en Adicionales (fallback de filas viejas)', (
    tester,
  ) async {
    const item = CartItem(
      id: 'cart-1',
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: [
        CartModifier(
          optionId: 'o-salami',
          optionName: 'Salami',
          action: CartModifierAction.added,
          priceDelta: 4000,
        ),
      ],
    );

    await tester.pumpWidget(_host(const CartItemDetailPanel(item: item)));

    expect(find.text('Adicionales'), findsOneWidget);
    expect(find.text(r'Salami +$4.000', findRichText: true), findsOneWidget);
    expect(find.text('Toppings'), findsNothing);
    expect(find.text('Salsas'), findsNothing);
  });

  testWidgets(
    'reemplazo gratis → "Se le quitó: agotado → reemplazo" sin repetir '
    'en Adicionales',
    (tester) async {
      const item = CartItem(
        id: 'cart-1',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        includedNames: ['Pan artesanal', 'Salchicha americana'],
        modifiers: [
          CartModifier(
            optionId: 'o-mozzarella',
            optionName: 'Queso mozzarella',
            action: CartModifierAction.removed,
            priceDelta: 0,
            group: CartModifierGroup.ingredient,
          ),
          CartModifier(
            optionId: 'o-tocineta',
            optionName: 'Tocineta crocante',
            action: CartModifierAction.added,
            priceDelta: 0,
            replacesOptionId: 'o-mozzarella',
            group: CartModifierGroup.ingredient,
          ),
        ],
      );

      await tester.pumpWidget(_host(const CartItemDetailPanel(item: item)));

      // El vínculo se comunica en "Se le quitó" — la fila added del
      // reemplazo no reaparece suelta en "Adicionales".
      expect(find.text('Se le quitó'), findsOneWidget);
      expect(find.text('Queso mozzarella → Tocineta crocante'), findsOneWidget);
      expect(find.text('Adicionales'), findsNothing);
    },
  );

  testWidgets('ítem vacío (sin snapshot ni modifiers) → fallback', (
    tester,
  ) async {
    const item = CartItem(
      id: 'cart-1',
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: [],
    );

    await tester.pumpWidget(_host(const CartItemDetailPanel(item: item)));

    expect(find.text('Tal cual de la carta'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
  });
}
