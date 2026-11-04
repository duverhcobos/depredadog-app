import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/logging/interfaces/i_logger_service.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/failures/catalog_failure.dart';
import 'package:depredadog_app/features/home/domain/use_cases/get_catalog_menu_use_case.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_cubit.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_state.dart';

class MockGetCatalogMenuUseCase extends Mock implements GetCatalogMenuUseCase {}

class MockLogger extends Mock implements ILoggerService {}

void main() {
  late MockGetCatalogMenuUseCase useCase;
  late MockLogger logger;

  const menu = <CatalogCategory>[
    CatalogCategory(id: 'cat-1', slug: 'perros', name: 'Perros', products: []),
  ];

  const menuNuevo = <CatalogCategory>[
    CatalogCategory(id: 'cat-1', slug: 'perros', name: 'Perros', products: []),
    CatalogCategory(
      id: 'cat-2',
      slug: 'bebidas',
      name: 'Bebidas',
      products: [],
    ),
  ];

  setUp(() {
    useCase = MockGetCatalogMenuUseCase();
    logger = MockLogger();
  });

  CatalogCubit buildCubit() =>
      CatalogCubit(getCatalogMenuUseCase: useCase, logger: logger);

  void stubMenu(Either<CatalogFailure, List<CatalogCategory>> result) =>
      when(() => useCase()).thenAnswer((_) async => result);

  group('CatalogCubit.load', () {
    blocTest<CatalogCubit, CatalogState>(
      'desde initial → loading → success con el menú',
      build: buildCubit,
      setUp: () => stubMenu(const Right(menu)),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading, categories: []),
        const CatalogState(status: CatalogStatus.success, categories: menu),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'falla sin datos → loading → error con failure',
      build: buildCubit,
      setUp: () => stubMenu(const Left(CatalogOfflineFailure())),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading, categories: []),
        const CatalogState(
          status: CatalogStatus.error,
          categories: [],
          failure: CatalogOfflineFailure(),
        ),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'con éxito previo y sin forceRefresh → NO emite (no-op) ni re-pide',
      build: buildCubit,
      seed: () =>
          const CatalogState(status: CatalogStatus.success, categories: menu),
      act: (cubit) => cubit.load(),
      expect: () => <CatalogState>[],
      verify: (_) => verifyNever(() => useCase()),
    );

    blocTest<CatalogCubit, CatalogState>(
      'dos load() concurrentes → el use case se llama UNA vez (dedupe)',
      build: buildCubit,
      setUp: () => stubMenu(const Right(menu)),
      act: (cubit) => Future.wait([cubit.load(), cubit.load()]),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading, categories: []),
        const CatalogState(status: CatalogStatus.success, categories: menu),
      ],
      verify: (_) => verify(() => useCase()).called(1),
    );
  });

  group('CatalogCubit.refresh', () {
    blocTest<CatalogCubit, CatalogState>(
      'con datos → success con menú nuevo (sin pasar por loading)',
      build: buildCubit,
      seed: () =>
          const CatalogState(status: CatalogStatus.success, categories: menu),
      setUp: () => stubMenu(const Right(menuNuevo)),
      act: (cubit) => cubit.refresh(),
      expect: () => [
        const CatalogState(
          status: CatalogStatus.success,
          categories: menuNuevo,
        ),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'mismo id con flag cambiada (agotado) → SÍ emite (igualdad por '
      'valor — regresión del bug del refresh silencioso)',
      build: buildCubit,
      seed: () => const CatalogState(
        status: CatalogStatus.success,
        categories: [
          CatalogCategory(
            id: 'cat-1',
            slug: 'perros',
            name: 'Perros',
            products: [
              CatalogProduct(
                id: 'p-1',
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
            ],
          ),
        ],
      ),
      setUp: () => stubMenu(
        const Right([
          CatalogCategory(
            id: 'cat-1',
            slug: 'perros',
            name: 'Perros',
            products: [
              CatalogProduct(
                id: 'p-1',
                slug: 'coyote',
                name: 'El Coyote',
                tagline: 'Cacería del desierto.',
                basePrice: 18000,
                imageUrl: null,
                isAvailable: false,
                isFeatured: false,
                isCombo: false,
                modifierGroups: [],
              ),
            ],
          ),
        ]),
      ),
      act: (cubit) => cubit.refresh(),
      expect: () => [
        isA<CatalogState>().having(
          (s) => s.categories.first.products.first.isAvailable,
          'producto refrescado a agotado',
          false,
        ),
      ],
    );

    blocTest<CatalogCubit, CatalogState>(
      'falla con datos → NO emite error: queda success con los datos '
      'viejos + warning en logger',
      build: buildCubit,
      seed: () =>
          const CatalogState(status: CatalogStatus.success, categories: menu),
      setUp: () => stubMenu(const Left(CatalogServerFailure('boom'))),
      act: (cubit) => cubit.refresh(),
      expect: () => <CatalogState>[],
      verify: (_) {
        verify(() => logger.warning(any(), tag: any(named: 'tag'))).called(1);
      },
    );
  });
}
