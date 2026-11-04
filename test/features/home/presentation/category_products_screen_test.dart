import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/presentation/data/catalog_mock.dart';
import 'package:depredadog_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:depredadog_app/features/home/presentation/screens/product_detail_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/home/category/combos',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(),
          routes: [
            GoRoute(
              path: 'category/:categoryId',
              builder: (context, state) => CategoryProductsScreen(
                category: CatalogCategoryX.fromSegment(
                  state.pathParameters['categoryId'] ?? '',
                ),
              ),
              routes: [
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) => ProductDetailScreen(
                    item: catalogItemById(
                      state.pathParameters['productId'] ?? '',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpList(WidgetTester tester, String initialLocation) {
    final router = buildRouter()..go(initialLocation);
    return tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
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
    await pumpList(tester, '/home/category/combos');
    await tester.pumpAndSettle();

    expect(find.text('Combos'), findsOneWidget);
    expect(find.text('Disponible próximamente'), findsOneWidget);
  });

  testWidgets('tap en card de producto abre el detalle de personalización', (
    tester,
  ) async {
    await pumpList(tester, '/home/category/mas');
    await tester.pumpAndSettle();
    expect(find.text('Manada de Papas'), findsOneWidget);

    await tester.tap(find.text('Manada de Papas'));
    await tester.pumpAndSettle();

    // Detalle abierto: CTA en footer + sección de adicionales visible.
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(find.text('¿Le agregamos algo más?'), findsOneWidget);
  });
}
