import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_cubit.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_state.dart';
import 'package:depredadog_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:depredadog_app/features/home/presentation/screens/product_detail_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockCatalogCubit extends MockCubit<CatalogState>
    implements CatalogCubit {}

// Fixtures de dominio equivalentes al mock viejo (§017) — mismos
// nombres/precios para no reescribir aserciones.
const _menu = [
  CatalogCategory(
    id: 'cat-perros',
    slug: 'perros',
    name: 'Perros',
    products: [
      CatalogProduct(
        id: 'p-cachorro',
        slug: 'cachorro',
        name: 'El Cachorro',
        tagline: 'El primer mordisco de la manada.',
        basePrice: 14000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: false,
        isCombo: false,
        modifierGroups: [],
      ),
      CatalogProduct(
        id: 'p-depredador',
        slug: 'depredador',
        name: 'El Depredador',
        tagline: 'El alfa come de todo.',
        basePrice: 25000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: true,
        isCombo: false,
        modifierGroups: [],
      ),
    ],
  ),
  CatalogCategory(
    id: 'cat-mas',
    slug: 'mas',
    name: '& Más',
    products: [
      CatalogProduct(
        id: 'p-papas',
        slug: 'manada-papas',
        name: 'Manada de Papas',
        tagline: 'Con las salsas de la casa.',
        basePrice: 10000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: false,
        isCombo: false,
        modifierGroups: [],
      ),
    ],
  ),
  CatalogCategory(
    id: 'cat-combos',
    slug: 'combos',
    name: 'Combos',
    products: [],
  ),
];

void main() {
  late MockCatalogCubit cubit;

  void seedState(CatalogState state) {
    whenListen(cubit, const Stream<CatalogState>.empty(), initialState: state);
  }

  setUp(() {
    cubit = MockCatalogCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/home/category/combos',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(),
          routes: [
            GoRoute(
              path: 'category/:categorySlug',
              builder: (context, state) => CategoryProductsScreen(
                categorySlug: state.pathParameters['categorySlug'] ?? '',
              ),
              routes: [
                GoRoute(
                  path: 'product/:productSlug',
                  builder: (context, state) => ProductDetailScreen(
                    productSlug: state.pathParameters['productSlug'] ?? '',
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
      BlocProvider<CatalogCubit>.value(
        value: cubit,
        child: MaterialApp.router(
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
      ),
    );
  }

  testWidgets('Perros: hero Depredador + resto como cards', (tester) async {
    seedState(
      const CatalogState(status: CatalogStatus.success, categories: _menu),
    );
    await pumpList(tester, '/home/category/perros');
    await tester.pumpAndSettle();

    expect(find.text('Perros'), findsOneWidget);
    expect(find.text('EL DE LA CASA'), findsOneWidget);
    expect(find.text('El Depredador'), findsOneWidget);
    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text(r'$25.000'), findsOneWidget);
    expect(find.text(r'$14.000'), findsOneWidget);

    // Tagline de la card: máximo 2 líneas (decisión §017).
    final tagline = tester.widget<Text>(
      find.text('El primer mordisco de la manada.'),
    );
    expect(tagline.maxLines, 2);
  });

  testWidgets('el "+" de Cachorro navega al detalle por slug', (tester) async {
    seedState(
      const CatalogState(status: CatalogStatus.success, categories: _menu),
    );
    await pumpList(tester, '/home/category/perros');
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('El Cachorro'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pumpAndSettle();

    // Detalle abierto por productSlug=cachorro: CTA + sección extras.
    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);
    expect(find.text('¿Le agregamos algo más?'), findsOneWidget);
  });

  testWidgets('categoría vacía muestra la card fantasma', (tester) async {
    seedState(
      const CatalogState(status: CatalogStatus.success, categories: _menu),
    );
    await pumpList(tester, '/home/category/combos');
    await tester.pumpAndSettle();

    expect(find.text('Combos'), findsOneWidget);
    expect(find.text('Disponible próximamente'), findsOneWidget);
    expect(find.text('La manada aún está cazando aquí'), findsOneWidget);
  });

  testWidgets('primera carga → spinner de loading', (tester) async {
    seedState(
      const CatalogState(status: CatalogStatus.loading, categories: []),
    );
    await pumpList(tester, '/home/category/perros');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error sin caché → vista de error + Reintentar re-pide', (
    tester,
  ) async {
    seedState(
      const CatalogState(
        status: CatalogStatus.error,
        categories: [],
        failure: null,
      ),
    );
    await pumpList(tester, '/home/category/perros');
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar la carta'), findsOneWidget);
    expect(
      find.text('Revisa tu conexión e inténtalo de nuevo.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    // Una vez en initState + una por el retry.
    verify(() => cubit.refresh()).called(2);
  });
}
