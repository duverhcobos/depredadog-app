import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/auth/auth_storage_keys.dart';
import 'package:depredadog_app/core/auth/token_refresh_service.dart';
import 'package:depredadog_app/core/logging/interfaces/i_logger_service.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_service.dart';
import 'package:depredadog_app/core/storage/interfaces/i_secure_storage.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';

class MockNetworkService extends Mock implements INetworkService {}

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockLoggerService extends Mock implements ILoggerService {}

void main() {
  late MockNetworkService network;
  late MockSecureStorage storage;
  late AuthSession session;
  late TokenRefreshService service;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  /// Sesión "viva" para poder verificar que markLoggedOut la cierra (o
  /// que un fallo transitorio la deja intacta).
  void markLoggedIn() => session.markAuthenticated(user);

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    network = MockNetworkService();
    storage = MockSecureStorage();
    session = AuthSession();
    service = TokenRefreshService(
      networkService: network,
      secureStorage: storage,
      session: session,
      logger: MockLoggerService(),
    );
  });

  void stubRefreshToken(String? token) => when(
    () => storage.read(AuthStorageKeys.refreshToken),
  ).thenAnswer((_) async => token);

  group('TokenRefreshService.refresh', () {
    test('sin refresh token devuelve false sin tocar la red', () async {
      stubRefreshToken(null);

      final result = await service.refresh();

      expect(result, isFalse);
      verifyNever(() => network.post(any(), body: any(named: 'body')));
    });

    test('refresh token vacío devuelve false sin tocar la red', () async {
      stubRefreshToken('');

      final result = await service.refresh();

      expect(result, isFalse);
      verifyNever(() => network.post(any(), body: any(named: 'body')));
    });

    test('éxito escribe el par rotado en storage y devuelve true', () async {
      stubRefreshToken('refresh-viejo');
      when(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {
          'accessToken': 'access-nuevo',
          'refreshToken': 'refresh-nuevo',
        },
      );
      when(() => storage.write(any(), any())).thenAnswer((_) async {});

      final result = await service.refresh();

      expect(result, isTrue);
      verify(
        () => network.post(
          '/auth/refresh',
          body: {'refreshToken': 'refresh-viejo'},
        ),
      ).called(1);
      verify(
        () => storage.write(AuthStorageKeys.accessToken, 'access-nuevo'),
      ).called(1);
      verify(
        () => storage.write(AuthStorageKeys.refreshToken, 'refresh-nuevo'),
      ).called(1);
      verifyNever(() => storage.deleteKeys(any()));
      expect(session.isAuthenticated, isFalse); // nunca se tocó la sesión
    });

    test('401 borra ambas claves, cierra la sesión y devuelve false', () async {
      stubRefreshToken('refresh-viejo');
      markLoggedIn();
      when(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).thenThrow(const UnauthorizedException());
      when(() => storage.deleteKeys(any())).thenAnswer((_) async {});

      final result = await service.refresh();

      expect(result, isFalse);
      verify(
        () => storage.deleteKeys(const [
          AuthStorageKeys.accessToken,
          AuthStorageKeys.refreshToken,
        ]),
      ).called(1);
      expect(session.isAuthenticated, isFalse);
      expect(session.currentUser, isNull);
    });

    test('403 (ServerException) también cierra la sesión', () async {
      stubRefreshToken('refresh-viejo');
      markLoggedIn();
      when(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).thenThrow(const ServerException('Forbidden', statusCode: 403));
      when(() => storage.deleteKeys(any())).thenAnswer((_) async {});

      final result = await service.refresh();

      expect(result, isFalse);
      verify(
        () => storage.deleteKeys(const [
          AuthStorageKeys.accessToken,
          AuthStorageKeys.refreshToken,
        ]),
      ).called(1);
      expect(session.isAuthenticated, isFalse);
    });

    test(
      'NoConnectionException devuelve false y las claves quedan intactas',
      () async {
        stubRefreshToken('refresh-viejo');
        markLoggedIn();
        when(
          () => network.post('/auth/refresh', body: any(named: 'body')),
        ).thenThrow(const NoConnectionException());

        final result = await service.refresh();

        expect(result, isFalse);
        verifyNever(() => storage.deleteKeys(any()));
        verifyNever(() => storage.delete(any()));
        expect(session.isAuthenticated, isTrue); // la sesión sigue viva
      },
    );

    test('5xx es transitorio: devuelve false sin borrar claves', () async {
      stubRefreshToken('refresh-viejo');
      markLoggedIn();
      when(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      final result = await service.refresh();

      expect(result, isFalse);
      verifyNever(() => storage.deleteKeys(any()));
      expect(session.isAuthenticated, isTrue);
    });

    test(
      'dos refresh() concurrentes hacen un solo POST (single-flight)',
      () async {
        stubRefreshToken('refresh-viejo');
        final completer = Completer<dynamic>();
        when(
          () => network.post('/auth/refresh', body: any(named: 'body')),
        ).thenAnswer((_) => completer.future);
        when(() => storage.write(any(), any())).thenAnswer((_) async {});

        final first = service.refresh();
        final second = service.refresh();

        completer.complete({
          'accessToken': 'access-nuevo',
          'refreshToken': 'refresh-nuevo',
        });

        expect(await first, isTrue);
        expect(await second, isTrue);
        verify(
          () => network.post('/auth/refresh', body: any(named: 'body')),
        ).called(1);
      },
    );

    test('tras completar, el próximo refresh vuelve a pegarle a la red', () async {
      stubRefreshToken('refresh-viejo');
      when(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {
          'accessToken': 'access-nuevo',
          'refreshToken': 'refresh-nuevo',
        },
      );
      when(() => storage.write(any(), any())).thenAnswer((_) async {});

      await service.refresh();
      await service.refresh();

      verify(
        () => network.post('/auth/refresh', body: any(named: 'body')),
      ).called(2);
    });
  });
}
