import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/features/home/data/datasources/interfaces/i_catalog_remote_datasource.dart';
import 'package:depredadog_app/features/home/data/models/catalog_models.dart';
import 'package:depredadog_app/features/home/data/repositories/catalog_repository_impl.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/failures/catalog_failure.dart';

class MockRemoteDataSource extends Mock implements ICatalogRemoteDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockRemoteDataSource remote;
  late MockNetworkInfo networkInfo;
  late CatalogRepositoryImpl repository;

  const menu = <CatalogCategoryModel>[
    CatalogCategoryModel(
      id: 'cat-1',
      slug: 'perros',
      name: 'Perros',
      products: [],
    ),
  ];

  setUp(() {
    remote = MockRemoteDataSource();
    networkInfo = MockNetworkInfo();
    repository = CatalogRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  group('CatalogRepositoryImpl.getMenu', () {
    test('éxito con conectividad → Right(menu)', () async {
      when(() => remote.fetchMenu()).thenAnswer((_) async => menu);

      final result = await repository.getMenu();

      expect(result, const Right<CatalogFailure, List<CatalogCategory>>(menu));
      verify(() => remote.fetchMenu()).called(1);
    });

    test('sin conectividad → Left(CatalogOfflineFailure) y el datasource '
        'NUNCA se llama', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.getMenu();

      expect(
        result,
        const Left<CatalogFailure, List<CatalogCategory>>(
          CatalogOfflineFailure(),
        ),
      );
      verifyNever(() => remote.fetchMenu());
    });

    test(
      'NoConnectionException del datasource → CatalogOfflineFailure',
      () async {
        when(() => remote.fetchMenu()).thenThrow(const NoConnectionException());

        final result = await repository.getMenu();

        expect(
          result,
          const Left<CatalogFailure, List<CatalogCategory>>(
            CatalogOfflineFailure(),
          ),
        );
      },
    );

    test('ServerException (500) → CatalogServerFailure', () async {
      when(() => remote.fetchMenu())
          .thenThrow(const ServerException('Internal error', statusCode: 500));

      final result = await repository.getMenu();

      expect(
        result,
        const Left<CatalogFailure, List<CatalogCategory>>(
          CatalogServerFailure('Internal error'),
        ),
      );
    });

    test('error no-NetworkException (cast roto de un 200) → '
        'CatalogServerFailure (red de seguridad)', () async {
      when(() => remote.fetchMenu()).thenThrow(StateError('bad cast'));

      final result = await repository.getMenu();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CatalogServerFailure>()),
        (_) => fail('esperaba Left'),
      );
    });
  });
}
