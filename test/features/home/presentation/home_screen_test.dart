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
import 'package:depredadog_app/features/home/presentation/screens/home_screen.dart';
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
        id: 'p-trampa',
        slug: 'trampa',
        name: 'La Trampa',
        tagline: 'Lo dulce es el anzuelo.',
        basePrice: 16000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: false,
        isCombo: false,
        modifierGroups: [],
      ),
      CatalogProduct(
        id: 'p-ave',
        slug: 'ave-presa',
        name: 'Ave de Presa',
        tagline: 'Cayó directo del corral.',
        basePrice: 18000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: false,
        isCombo: false,
        modifierGroups: [],
      ),
      CatalogProduct(
        id: 'p-coyote',
        slug: 'coyote',
        name: 'El Coyote',
        tagline: 'Cacería del desierto.',
        basePrice: 18000,
        imageUrl: null,
        isAvailable: true,
        isFeatured: false,
        isCombo: false,
        modifierGroups: [],
      ),
      CatalogProduct(
        id: 'p-carnicero',
        slug: 'carnicero',
        name: 'El Carnicero',
        tagline: 'Carne sobre carne, sin piedad.',
        basePrice: 17000,
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
    id: 'cat-bebidas',
    slug: 'bebidas',
    name: 'Bebidas',
    products: [],
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

  setUp(() {
    cubit = MockCatalogCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<CatalogState>.empty(),
      initialState: const CatalogState(
        status: CatalogStatus.success,
        categories: _menu,
      ),
    );
  });

  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'category/:categorySlug',
              builder: (context, state) => CategoryProductsScreen(
                categorySlug: state.pathParameters['categorySlug'] ?? '',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpWidget(
      BlocProvider<CatalogCubit>.value(
        value: cubit,
        child: MaterialApp.router(
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
