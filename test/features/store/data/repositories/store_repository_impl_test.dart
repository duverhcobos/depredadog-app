import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_service.dart';
import 'package:depredadog_app/features/store/data/datasources/implementations/store_remote_datasource_impl.dart';
import 'package:depredadog_app/features/store/data/datasources/interfaces/i_store_remote_datasource.dart';
import 'package:depredadog_app/features/store/data/repositories/store_repository_impl.dart';
import 'package:depredadog_app/features/store/domain/entities/store_open_state.dart';
import 'package:depredadog_app/features/store/domain/failures/store_failure.dart';

class MockRemoteDataSource extends Mock implements IStoreRemoteDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockNetworkService extends Mock implements INetworkService {}

void main() {
  group('StoreRepositoryImpl.getOpenState (§029)', () {
    late MockRemoteDataSource remote;
    late MockNetworkInfo networkInfo;
    late StoreRepositoryImpl repository;

    setUp(() {
      remote = MockRemoteDataSource();
      networkInfo = MockNetworkInfo();
      repository = StoreRepositoryImpl(
        remoteDataSource: remote,
        networkInfo: networkInfo,
      );
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    test('isOpen:true → Right(open)', () async {
      when(
        () => remote.fetchOpenState(),
      ).thenAnswer((_) async => StoreOpenState.open);

      final result = await repository.getOpenState();

      expect(
        result,
        const Right<StoreFailure, StoreOpenState>(StoreOpenState.open),
      );
      verify(() => remote.fetchOpenState()).called(1);
    });

    test('isOpen:false → Right(closed)', () async {
      when(
        () => remote.fetchOpenState(),
      ).thenAnswer((_) async => StoreOpenState.closed);

      final result = await repository.getOpenState();

      expect(
        result,
        const Right<StoreFailure, StoreOpenState>(StoreOpenState.closed),
      );
    });

    test('body sin isOpen → el datasource degrada a unknown y el repo '
        'lo propaga tal cual (nunca un cerrado fingido)', () async {
      when(
        () => remote.fetchOpenState(),
      ).thenAnswer((_) async => StoreOpenState.unknown);

      final result = await repository.getOpenState();

      expect(
        result,
        const Right<StoreFailure, StoreOpenState>(StoreOpenState.unknown),
      );
    });

    test('NoConnectionException → Left(StoreFetchFailure)', () async {
      when(
        () => remote.fetchOpenState(),
      ).thenThrow(const NoConnectionException());

      final result = await repository.getOpenState();

      expect(
        result,
        const Left<StoreFailure, StoreOpenState>(
          StoreFetchFailure('No internet connection'),
        ),
      );
    });

    test('sin conectividad → Left(StoreFetchFailure) y el datasource '
        'NUNCA se llama', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.getOpenState();

      expect(
        result,
        const Left<StoreFailure, StoreOpenState>(
          StoreFetchFailure('Sin conexión'),
        ),
      );
      verifyNever(() => remote.fetchOpenState());
    });

    test('ServerException → Left(StoreFetchFailure) con su mensaje', () async {
      when(
        () => remote.fetchOpenState(),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      final result = await repository.getOpenState();

      expect(
        result,
        const Left<StoreFailure, StoreOpenState>(StoreFetchFailure('boom')),
      );
    });
  });

  group('StoreRemoteDataSourceImpl.fetchOpenState (§029 — parseo '
      'defensivo: solo isOpen bool manda)', () {
    late MockNetworkService networkService;
    late StoreRemoteDataSourceImpl datasource;

    setUp(() {
      networkService = MockNetworkService();
      datasource = StoreRemoteDataSourceImpl(networkService: networkService);
    });

    test('isOpen:true → open', () async {
      when(() => networkService.get('/store/config')).thenAnswer(
        (_) async => <String, dynamic>{'isOpen': true},
      );

      expect(await datasource.fetchOpenState(), StoreOpenState.open);
    });

    test('isOpen:false → closed', () async {
      when(() => networkService.get('/store/config')).thenAnswer(
        (_) async => <String, dynamic>{'isOpen': false},
      );

      expect(await datasource.fetchOpenState(), StoreOpenState.closed);
    });

    test('body sin isOpen → unknown', () async {
      when(() => networkService.get('/store/config')).thenAnswer(
        (_) async => <String, dynamic>{'name': 'Depredadog'},
      );

      expect(await datasource.fetchOpenState(), StoreOpenState.unknown);
    });

    test('isOpen no-bool → unknown', () async {
      when(() => networkService.get('/store/config')).thenAnswer(
        (_) async => <String, dynamic>{'isOpen': 'true'},
      );

      expect(await datasource.fetchOpenState(), StoreOpenState.unknown);
    });

    test('body no-Map → unknown', () async {
      when(
        () => networkService.get('/store/config'),
      ).thenAnswer((_) async => <dynamic>['x']);

      expect(await datasource.fetchOpenState(), StoreOpenState.unknown);
    });
  });
}
