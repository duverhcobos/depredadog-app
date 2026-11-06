import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:depredadog_app/features/cart/presentation/widgets/cart_item_tile.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

const _sinMozzarella = CartModifier(
  optionId: 'o-mozzarella',
  optionName: 'Queso mozzarella',
  action: CartModifierAction.removed,
  priceDelta: 0,
);
const _extraTocineta = CartModifier(
  optionId: 'o-tocineta',
  optionName: 'Tocineta crocante',
  action: CartModifierAction.added,
  priceDelta: 4000,
);

void main() {
  late CartCubit cartCubit;

  setUp(() => cartCubit = CartCubit());
  tearDown(() => cartCubit.close());

  /// Harness: cubit REAL (los métodos son síncronos — más simple que
  /// mockear) + MaterialApp con l10n. Sin GoRouter: los únicos call
  /// sites de router son la flecha back y "Ver el menú", que estos
  /// casos no disparan.
  Future<void> pumpCart(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<CartCubit>.value(
      value: cartCubit,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const CartScreen(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
      ),
    ),
  );

  void addCachorro({
    List<CartModifier> modifiers = const [],
    List<String> includedNames = const [],
  }) => cartCubit.addItem(
    productId: 'p-cachorro',
    productSlug: 'cachorro',
    productName: 'El Cachorro',
    unitBase: 14000,
    modifiers: modifiers,
    includedNames: includedNames,
  );

  testWidgets('vacío → título, empty view y CTA al menú; sin footer', (
    tester,
  ) async {
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.text('Tu carrito'), findsOneWidget);
    expect(find.text('Nada por acá todavía'), findsOneWidget);
    expect(find.text('Suma algo rico del menú'), findsOneWidget);
    expect(find.text('Ver el menú'), findsOneWidget);
    // Footer oculto sin ítems — y la ghost card solo existe en
    // lista no-vacía.
    expect(find.text('Ir a pagar'), findsNothing);
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('¿Se te antoja algo más?'), findsNothing);
  });

  testWidgets('2 ítems → nombres, chips Detalle y subtotal', (tester) async {
    addCachorro(modifiers: const [_sinMozzarella, _extraTocineta]);
    cartCubit.addItem(
      productId: 'p-trampa',
      productSlug: 'trampa',
      productName: 'La Trampa',
      unitBase: 18000,
      modifiers: const [],
    );
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text('La Trampa'), findsOneWidget);
    // El resumen de modificadores se retiró (§021b) — cada fila
    // lleva su chip "Detalle" para abrir el panel por secciones.
    expect(find.text('Detalle'), findsNWidgets(2));
    // unitPrice 18.000 (14.000 + 4.000) + 18.000 → $36.000.
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(r'$36.000'), findsOneWidget);
    expect(find.text('Ir a pagar'), findsOneWidget);
    // Ghost card de cierre (decisión del usuario — §020).
    expect(find.text('¿Se te antoja algo más?'), findsOneWidget);
  });

  testWidgets('tap en + del stepper → cantidad y totales crecen', (
    tester,
  ) async {
    addCachorro(modifiers: const [_extraTocineta]); // unitPrice 18.000
    await pumpCart(tester);
    await tester.pumpAndSettle();

    // byTooltip: el add_rounded de la ghost card compartía el icono.
    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    // lineTotal y subtotal coinciden: 2 × 18.000.
    expect(find.text(r'$36.000'), findsNWidgets(2));
  });

  testWidgets('− del stepper en qty 1 → la fila desaparece', (tester) async {
    addCachorro();
    await pumpCart(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CartItemTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CartItemTile), findsNothing);
    expect(find.text('Nada por acá todavía'), findsOneWidget);
  });

  testWidgets('qty 1 oculta el unitPrice; qty 2 lo muestra como metadata', (
    tester,
  ) async {
    addCachorro(modifiers: const [_extraTocineta]); // unitPrice 18.000
    await pumpCart(tester);
    await tester.pumpAndSettle();
    // qty 1: $18.000 solo ×2 (lineTotal del tile + Subtotal del
    // footer) — el unitPrice duplicado NO se suma (revisor-ui §020).
    expect(find.text(r'$18.000'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Agregar uno'));
    await tester.pumpAndSettle();
    // qty 2: unitPrice vuelve como metadata + lineTotal y subtotal
    // a $36.000.
    expect(find.text(r'$18.000'), findsOneWidget);
    expect(find.text(r'$36.000'), findsNWidgets(2));
  });

  testWidgets('ícono de basura del tile → la fila desaparece', (tester) async {
    addCachorro();
    await pumpCart(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CartItemTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CartItemTile), findsNothing);
    expect(find.text('Nada por acá todavía'), findsOneWidget);
  });

  testWidgets('swipe Dismissible endToStart → la fila desaparece', (
    tester,
  ) async {
    addCachorro();
    await pumpCart(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CartItemTile), findsOneWidget);

    await tester.fling(find.byType(CartItemTile), const Offset(-400, 0), 800);
    await tester.pumpAndSettle();

    expect(find.byType(CartItemTile), findsNothing);
    expect(find.text('Nada por acá todavía'), findsOneWidget);
  });

  testWidgets('CTA "Ir a pagar" existe (toast provisional no se verifica)', (
    tester,
  ) async {
    addCachorro();
    await pumpCart(tester);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Ir a pagar'), findsOneWidget);
  });

  testWidgets('tap en el chip Detalle despliega las secciones + Editar', (
    tester,
  ) async {
    addCachorro(
      modifiers: const [_sinMozzarella, _extraTocineta],
      includedNames: const ['Pan artesanal', 'Salchicha americana'],
    );
    await pumpCart(tester);
    await tester.pumpAndSettle();

    // Colapsado: el panel aún no existe.
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Ingredientes'), findsNothing);

    // El chip "Detalle" junto al título es el control del
    // desplegable (§021b).
    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Ingredientes'), findsOneWidget);
    expect(find.text('Pan artesanal'), findsOneWidget);
    expect(find.text('Salchicha americana'), findsOneWidget);
    expect(find.text('Se le quitó'), findsOneWidget);
    expect(find.text('Queso mozzarella'), findsOneWidget);
    expect(find.text('Adicionales'), findsOneWidget);
    expect(
      find.text(r'Tocineta crocante +$4.000', findRichText: true),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Editar'), findsOneWidget);
  });

  testWidgets('ítem sin personalización → chip Detalle abre el fallback', (
    tester,
  ) async {
    addCachorro(); // sin modifiers ni includedNames
    await pumpCart(tester);
    await tester.pumpAndSettle();

    // Colapsado no lleva texto de resumen (§021b) — solo el chip.
    expect(find.text('Detalle'), findsOneWidget);
    expect(find.text('Tal cual de la carta'), findsNothing);

    await tester.tap(find.text('Detalle'));
    await tester.pumpAndSettle();

    // Sin snapshot ni filas → fallback + Editar.
    expect(find.text('Tal cual de la carta'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Ingredientes'), findsNothing);
    expect(find.text('Se le quitó'), findsNothing);
    expect(find.text('Adicionales'), findsNothing);
  });
}
