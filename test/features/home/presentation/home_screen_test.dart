import 'package:flutter/material.dart';
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

  testWidgets('renderiza promo y las 4 categorías', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

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
