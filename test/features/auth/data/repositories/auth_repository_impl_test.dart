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
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  const loginResult = LoginResult(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: user,
  );

  void stubRemoteRegister(Future<UserModel> Function() answer) => when(
    () => remote.register(
      email: any(named: 'email'),
      password: any(named: 'password'),
      firstName: any(named: 'firstName'),
      secondName: any(named: 'secondName'),
      firstLastName: any(named: 'firstLastName'),
      secondLastName: any(named: 'secondLastName'),
      phone: any(named: 'phone'),
      deviceFingerprint: any(named: 'deviceFingerprint'),
      platform: any(named: 'platform'),
    ),
  ).thenAnswer((_) => answer());

  void stubRemoteRegisterThrows(NetworkException e) =>
      stubRemoteRegister(() => throw e);

  Future<Object> callRegister() => repository.register(
    email: 'ana@ejemplo.com',
    password: 'secreto123',
    firstName: 'Ana',
    secondName: 'María',
    firstLastName: 'Pérez',
    secondLastName: 'Gómez',
    phone: '3001234567',
  );

  void verifyNeverSaveSession() => verifyNever(
    () => local.saveSession(
      accessToken: any(named: 'accessToken'),
      refreshToken: any(named: 'refreshToken'),
    ),
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

  Future<Object> callLogin() =>
      repository.login(email: 'test@depredadog.com', password: 'secreto1');

  void stubRemoteVerify(Future<LoginResult> Function() answer) => when(
    () => remote.verifyEmail(
      email: any(named: 'email'),
      code: any(named: 'code'),
      deviceFingerprint: any(named: 'deviceFingerprint'),
      platform: any(named: 'platform'),
    ),
  ).thenAnswer((_) => answer());

  void stubRemoteVerifyThrows(NetworkException e) =>
      stubRemoteVerify(() => throw e);

  Future<Object> callVerify() =>
      repository.verifyEmail(email: 'test@depredadog.com', code: '123456');

  void stubRemoteResend(Future<void> Function() answer) =>
      when(() => remote.resendVerification(email: any(named: 'email')))
          .thenAnswer((_) => answer());

  void stubRemoteResendThrows(NetworkException e) =>
      stubRemoteResend(() => throw e);

  Future<Object> callResend() =>
      repository.resendVerification(email: 'test@depredadog.com');

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
    when(() => local.clearSession()).thenAnswer((_) async {});
  });

  group('AuthRepositoryImpl.register', () {
    test('éxito: devuelve el usuario SIN guardar sesión (register no '
        'emite tokens — el auto-login es de verify-email)', () async {
      stubRemoteRegister(() async => user);

      final result = await callRegister();

      expect(result, const Right<AuthFailure, UserModel>(user));
      verify(
        () => remote.register(
          email: 'ana@ejemplo.com',
          password: 'secreto123',
          firstName: 'Ana',
          secondName: 'María',
          firstLastName: 'Pérez',
          secondLastName: 'Gómez',
          phone: '3001234567',
          deviceFingerprint: 'fp-123',
          platform: 'android',
        ),
      ).called(1);
      // El endpoint devuelve solo UserResponseDto: saveSession NUNCA se
      // llama — no hay tokens que persistir.
      verifyNeverSaveSession();
    });

    test('opcionales ausentes: llegan null al datasource', () async {
      stubRemoteRegister(() async => user);

      await repository.register(
        email: 'ana@ejemplo.com',
        password: 'secreto123',
        firstName: 'Ana',
        firstLastName: 'Pérez',
      );

      verify(
        () => remote.register(
          email: 'ana@ejemplo.com',
          password: 'secreto123',
          firstName: 'Ana',
          secondName: null,
          firstLastName: 'Pérez',
          secondLastName: null,
          phone: null,
          deviceFingerprint: 'fp-123',
          platform: 'android',
        ),
      ).called(1);
    });

    test('sin conexión: NoConnectionFailure sin tocar el datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await callRegister();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
      verifyNever(
        () => remote.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          firstName: any(named: 'firstName'),
          secondName: any(named: 'secondName'),
          firstLastName: any(named: 'firstLastName'),
          secondLastName: any(named: 'secondLastName'),
          phone: any(named: 'phone'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
          platform: any(named: 'platform'),
        ),
      );
      verifyNeverSaveSession();
    });

    test('409 "Email is already registered" → '
        'EmailAlreadyRegisteredFailure', () async {
      stubRemoteRegisterThrows(
        const ServerException('Email is already registered', statusCode: 409),
      );

      final result = await callRegister();

      expect(
        result,
        const Left<AuthFailure, Object>(EmailAlreadyRegisteredFailure()),
      );
      verifyNeverSaveSession();
    });

    test('429 → TooManyAttemptsFailure', () async {
      stubRemoteRegisterThrows(
        const ServerException('Too many requests', statusCode: 429),
      );

      final result = await callRegister();

      expect(result, const Left<AuthFailure, Object>(TooManyAttemptsFailure()));
    });
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

      expect(result, const Left<AuthFailure, Object>(TooManyAttemptsFailure()));
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

  group('AuthRepositoryImpl.verifyEmail', () {
    test(
      'éxito: guarda la sesión y devuelve el usuario (auto-login)',
      () async {
        stubRemoteVerify(() async => loginResult);

        final result = await repository.verifyEmail(
          email: 'test@depredadog.com',
          code: '123456',
        );

        expect(result, const Right<AuthFailure, UserModel>(user));
        verify(
          () => remote.verifyEmail(
            email: 'test@depredadog.com',
            code: '123456',
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
      },
    );

    test('sin conexión: NoConnectionFailure sin tocar el datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await callVerify();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
      verifyNever(
        () => remote.verifyEmail(
          email: any(named: 'email'),
          code: any(named: 'code'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
          platform: any(named: 'platform'),
        ),
      );
    });

    test('400 "Invalid or expired code" → InvalidCodeFailure', () async {
      stubRemoteVerifyThrows(
        const ServerException('Invalid or expired code', statusCode: 400),
      );

      final result = await callVerify();

      expect(result, const Left<AuthFailure, Object>(InvalidCodeFailure()));
      verifyNever(
        () => local.saveSession(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('429 → TooManyAttemptsFailure', () async {
      stubRemoteVerifyThrows(
        const ServerException('Too many requests', statusCode: 429),
      );

      final result = await callVerify();

      expect(result, const Left<AuthFailure, Object>(TooManyAttemptsFailure()));
    });

    test(
      'respuesta malformada (cast del datasource) → UnknownAuthFailure',
      () async {
        // Un 200 sin la forma esperada revienta en el `as String` del
        // datasource — no es NetworkException: el catch genérico lo traduce
        // a Unknown en vez de dejarlo escapar al cubit.
        stubRemoteVerify(() => throw const FormatException('unexpected body'));

        final result = await callVerify();

        expect(
          result,
          const Left<AuthFailure, Object>(
            UnknownAuthFailure('FormatException: unexpected body'),
          ),
        );
      },
    );
  });

  group('AuthRepositoryImpl.resendVerification', () {
    test('éxito: Right(null) — el backend responde 200 siempre', () async {
      stubRemoteResend(() async {});

      final result = await repository.resendVerification(
        email: 'test@depredadog.com',
      );

      expect(result, const Right<AuthFailure, void>(null));
      verify(() => remote.resendVerification(email: 'test@depredadog.com'))
          .called(1);
      // Resend nunca toca la sesión — no emite tokens.
      verifyNever(
        () => local.saveSession(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test('sin conexión: NoConnectionFailure sin tocar el datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await callResend();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
      verifyNever(() => remote.resendVerification(email: any(named: 'email')));
    });

    test('429 → TooManyAttemptsFailure', () async {
      stubRemoteResendThrows(
        const ServerException('Too many requests', statusCode: 429),
      );

      final result = await callResend();

      expect(result, const Left<AuthFailure, Object>(TooManyAttemptsFailure()));
    });
  });

  group('AuthRepositoryImpl.restoreSession', () {
    void stubToken(String? token) =>
        when(() => local.readAccessToken()).thenAnswer((_) async => token);

    void stubRemoteGetMe(Future<UserModel> Function() answer) =>
        when(() => remote.getMe()).thenAnswer((_) => answer());

    test(
      'sin token guardado: NoStoredSessionFailure sin tocar red ni remoto',
      () async {
        stubToken(null);

        final result = await repository.restoreSession();

        expect(
          result,
          const Left<AuthFailure, Object>(NoStoredSessionFailure()),
        );
        verifyNever(() => networkInfo.isConnected);
        verifyNever(() => remote.getMe());
      },
    );

    test(
      'token vacío: igual que sin token — fast path a NoStoredSession',
      () async {
        stubToken('');

        final result = await repository.restoreSession();

        expect(
          result,
          const Left<AuthFailure, Object>(NoStoredSessionFailure()),
        );
        verifyNever(() => remote.getMe());
      },
    );

    test(
      'offline: NoConnectionFailure conservando los tokens (no es logout)',
      () async {
        stubToken('access-token');
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.restoreSession();

        expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
        verifyNever(() => remote.getMe());
        verifyNever(() => local.clearSession());
      },
    );

    test('200 → Right(user): la sesión guardada sigue válida', () async {
      stubToken('access-token');
      stubRemoteGetMe(() async => user);

      final result = await repository.restoreSession();

      expect(result, const Right<AuthFailure, UserModel>(user));
      verify(() => remote.getMe()).called(1);
      // El restore nunca reescribe ni borra la sesión cuando es válida.
      verifyNever(() => local.clearSession());
      verifyNever(
        () => local.saveSession(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      );
    });

    test(
      '401 → SessionExpiredFailure y limpia los tokens (sesión muerta)',
      () async {
        stubToken('access-token');
        stubRemoteGetMe(() => throw const UnauthorizedException());

        final result = await repository.restoreSession();

        expect(
          result,
          const Left<AuthFailure, Object>(SessionExpiredFailure()),
        );
        verify(() => local.clearSession()).called(1);
      },
    );

    test('getMe lanza NoConnectionException (timeout con checker online): '
        'NoConnectionFailure conservando los tokens', () async {
      stubToken('access-token');
      stubRemoteGetMe(() => throw const NoConnectionException());

      final result = await repository.restoreSession();

      expect(result, const Left<AuthFailure, Object>(NoConnectionFailure()));
      verifyNever(() => local.clearSession());
    });

    test(
      '500 → UnknownAuthFailure conservando los tokens (error transitorio)',
      () async {
        stubToken('access-token');
        stubRemoteGetMe(
          () => throw const ServerException('Boom', statusCode: 500),
        );

        final result = await repository.restoreSession();

        expect(
          result,
          const Left<AuthFailure, Object>(UnknownAuthFailure('Boom')),
        );
        verifyNever(() => local.clearSession());
      },
    );
  });
}
