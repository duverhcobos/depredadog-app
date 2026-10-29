import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/device/interfaces/i_device_info_provider.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/features/auth/data/datasources/interfaces/i_auth_local_datasource.dart';
import 'package:depredadog_app/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart';
import 'package:depredadog_app/features/auth/data/models/user_model.dart';
import 'package:depredadog_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';

class MockRemoteDataSource extends Mock implements IAuthRemoteDataSource {}

class MockLocalDataSource extends Mock implements IAuthLocalDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockDeviceInfoProvider extends Mock implements IDeviceInfoProvider {}

void main() {
  late MockRemoteDataSource remote;
  late MockLocalDataSource local;
  late MockNetworkInfo networkInfo;
  late MockDeviceInfoProvider deviceInfo;
  late AuthRepositoryImpl repository;

  const user = UserModel(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    lastName: 'User',
    role: 'customer',
    status: 'active',
  );

  const loginResult = LoginResult(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: user,
  );

  void stubRemoteLogin(Future<LoginResult> Function() answer) => when(
    () => remote.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
      deviceFingerprint: any(named: 'deviceFingerprint'),
      platform: any(named: 'platform'),
    ),
  ).thenAnswer((_) => answer());

  void stubRemoteThrows(NetworkException e) => stubRemoteLogin(() => throw e);

  Future<Object> callLogin() => repository.login(
    email: 'test@depredadog.com',
    password: 'secreto1',
  );

  setUp(() {
    remote = MockRemoteDataSource();
    local = MockLocalDataSource();
    networkInfo = MockNetworkInfo();
    deviceInfo = MockDeviceInfoProvider();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      networkInfo: networkInfo,
      deviceInfoProvider: deviceInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => deviceInfo.fingerprint()).thenAnswer((_) async => 'fp-123');
    when(() => deviceInfo.platform).thenReturn('android');
    when(
      () => local.saveSession(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
  });

  group('AuthRepositoryImpl.login', () {
    test('éxito: guarda la sesión y devuelve el usuario', () async {
      stubRemoteLogin(() async => loginResult);

      final result = await repository.login(
        email: 'test@depredadog.com',
        password: 'secreto1',
      );

      expect(result, const Right<AuthFailure, UserModel>(user));
      verify(
        () => remote.login(
          email: 'test@depredadog.com',
          password: 'secreto1',
          deviceFingerprint: 'fp-123',
          platform: 'android',
        ),
      ).called(1);
      verify(
        () => local.saveSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      ).called(1);
    });

    test('sin conexión: NoConnectionFailure sin tocar el datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await callLogin();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
      verifyNever(
        () => remote.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
          platform: any(named: 'platform'),
        ),
      );
    });

    test('401 → InvalidCredentialsFailure', () async {
      stubRemoteThrows(const UnauthorizedException());

      final result = await callLogin();

      expect(
        result,
        const Left<AuthFailure, Object>(InvalidCredentialsFailure()),
      );
      verifyNever(
        () => local.saveSession(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('403 "Email is not verified" → EmailNotVerifiedFailure', () async {
      stubRemoteThrows(
        const ServerException('Email is not verified', statusCode: 403),
      );

      final result = await callLogin();

      expect(
        result,
        const Left<AuthFailure, Object>(EmailNotVerifiedFailure()),
      );
    });

    test('403 "Account is suspended" → AccountSuspendedFailure', () async {
      stubRemoteThrows(
        const ServerException('Account is suspended', statusCode: 403),
      );

      final result = await callLogin();

      expect(
        result,
        const Left<AuthFailure, Object>(AccountSuspendedFailure()),
      );
    });

    test('429 → TooManyAttemptsFailure', () async {
      stubRemoteThrows(
        const ServerException('Too many requests', statusCode: 429),
      );

      final result = await callLogin();

      expect(
        result,
        const Left<AuthFailure, Object>(TooManyAttemptsFailure()),
      );
    });

    test('error desconocido → UnknownAuthFailure con el mensaje', () async {
      stubRemoteThrows(const ServerException('Boom', statusCode: 500));

      final result = await callLogin();

      expect(
        result,
        const Left<AuthFailure, Object>(UnknownAuthFailure('Boom')),
      );
    });

    test('NoConnectionException → NoConnectionFailure', () async {
      stubRemoteThrows(const NoConnectionException());

      final result = await callLogin();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
    });
  });
}
