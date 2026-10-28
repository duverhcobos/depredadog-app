# Propuesta 004: Integración `/auth/login`

Primer endpoint real de la feature auth (fase 2 del `screen-first-workflow`).
Conecta `LoginScreen`/`LoginCubit` (ya aprobados visualmente, propuesta 003) contra
`POST /auth/login` del backend (`documentacion/api/auth/004-post-login.md`).

Decisiones ya confirmadas con el usuario:

| Decisión | Resultado |
|---|---|
| Persistencia de sesión ("Recuérdame") | **Siempre persiste** en `flutter_secure_storage` — el checkbox queda sin efecto funcional todavía (reservado a futuro) |
| Device fingerprint | **Se agrega** `device_info_plus` — login manda `platform` + `deviceFingerprint` reales |
| Interceptor de auth | **Se agrega ahora**, solo adjunta `Authorization: Bearer` — el refresh-on-401 queda para el ciclo de `/auth/refresh` |
| Restaurar sesión al abrir la app | **Diferido explícitamente** — queda anotado en `pendientes/` (se resuelve junto con `/auth/me`) |

Hallazgo de seguridad encontrado al diseñar esta propuesta (se corrige en el mismo
cambio): `LogInterceptor` (activo solo en dev) tiene `requestHeader`/`responseHeader`
en `true` por defecto en Dio — hoy no importa porque no hay headers sensibles, pero
en cuanto el `AuthInterceptor` empiece a mandar `Authorization: Bearer <token>` se
imprimiría en la consola de debug. Se desactivan ambos explícitamente.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | Ejecutar `flutter pub add device_info_plus` (no editar a mano) |
| `lib/features/auth/domain/entities/user.dart` | Nuevo |
| `lib/features/auth/domain/failures/auth_failure.dart` | Nuevo |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Nuevo |
| `lib/features/auth/domain/use_cases/login_use_case.dart` | Nuevo |
| `lib/features/auth/data/models/user_model.dart` | Nuevo |
| `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart` | Nuevo |
| `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart` | Nuevo |
| `lib/features/auth/data/datasources/interfaces/i_auth_local_datasource.dart` | Nuevo |
| `lib/features/auth/data/datasources/implementations/auth_local_datasource_impl.dart` | Nuevo |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Nuevo |
| `lib/core/auth/auth_storage_keys.dart` | Nuevo |
| `lib/core/auth/auth_session.dart` | Nuevo |
| `lib/core/device/interfaces/i_device_info_provider.dart` | Nuevo |
| `lib/core/device/implementations/device_info_provider_impl.dart` | Nuevo |
| `lib/core/network/interceptors/auth_interceptor.dart` | Nuevo |
| `lib/core/network/implementations/dio_network_service_impl.dart` | Actualizar — interceptores extra + fix de logging de headers |
| `lib/core/di/setup_di.dart` | Actualizar — registrar todo lo nuevo, `AuthGuard` lee `AuthSession` real |
| `lib/features/auth/presentation/cubit/login_state.dart` | Actualizar — nuevo status `authError` + campo `authFailure` |
| `lib/features/auth/presentation/cubit/login_cubit.dart` | Actualizar — `submit()` real contra el use case |
| `lib/features/auth/presentation/screens/login_screen.dart` | Actualizar — listener mapea `authFailure` a mensaje; éxito navega a `/home` |
| `lib/l10n/app_es.arb` + `flutter gen-l10n` | Actualizar — claves de error nuevas, se quita `loginDemoSuccess` |
| `pendientes/00X-restaurar-sesion.md` | Nuevo — pendiente explícito de la sesión diferida |

---

## 1. User (entidad de dominio)

**Ruta:** `lib/features/auth/domain/entities/user.dart`

```dart
import 'package:equatable/equatable.dart';

/// SOLID (SRP): representa al usuario autenticado — solo los campos que la
/// app usa hoy (MVP). El resto de UserResponseDto (phone, emailVerifiedAt,
/// referralCode, marketingOptIn, createdAt) se suma cuando una pantalla
/// real los necesite, sin romper este contrato.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
  });

  final String id;
  final String email;
  final String firstName;
  final String? lastName;

  /// Valores del backend: 'customer' | 'admin'.
  final String role;

  /// Valores del backend: 'pending_verification' | 'active' | 'suspended'.
  final String status;

  @override
  List<Object?> get props => [id, email, firstName, lastName, role, status];
}
```

---

## 2. AuthFailure (fallos de dominio)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

```dart
import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de auth — el repository
/// impl es el único que traduce NetworkException → AuthFailure; la UI
/// solo hace pattern-matching para elegir el mensaje (nunca ve el texto
/// crudo del backend).
sealed class AuthFailure extends Equatable {
  const AuthFailure();

  @override
  List<Object?> get props => [];
}

/// 401 en /auth/login — mismo mensaje para email inexistente, password
/// errado o cuenta solo-Google (anti-enumeración, ya lo hace el backend).
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// 403 — cuenta sin verificar el correo todavía.
class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure();
}

/// 403 — cuenta suspendida por un administrador.
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure();
}

/// 429 — rate limit del endpoint (5 req/min en el backend).
class TooManyAttemptsFailure extends AuthFailure {
  const TooManyAttemptsFailure();
}

/// Sin conectividad (INetworkInfo o timeout de conexión).
class NoConnectionFailure extends AuthFailure {
  const NoConnectionFailure();
}

/// Cualquier otro error no mapeado — conserva el mensaje del backend solo
/// para logging/depuración, la UI muestra un texto genérico propio.
class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

---

## 3. IAuthRepository

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';

/// SOLID (DIP): la capa de aplicación depende de esta interfaz, nunca de
/// AuthRepositoryImpl directo (solo setup_di.dart la conoce).
abstract class IAuthRepository {
  /// Autentica con email/password. Si tiene éxito, el repositorio ya dejó
  /// la sesión persistida (tokens en secure storage) — el caller solo
  /// recibe el User.
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  });
}
```

---

## 4. LoginUseCase

**Ruta:** `lib/features/auth/domain/use_cases/login_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): una acción de negocio — login. Hoy es un passthrough al
/// repositorio, pero es el punto de extensión para reglas futuras (ej.
/// analítica de login, lockout local tras N fallos) sin tocar el cubit.
class LoginUseCase {
  const LoginUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String password,
  }) => _repository.login(email: email, password: password);
}
```

---

## 5. UserModel

**Ruta:** `lib/features/auth/data/models/user_model.dart`

```dart
import '../../domain/entities/user.dart';

/// SOLID (SRP): única clase que conoce el JSON de UserResponseDto.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.role,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String?,
    role: json['role'] as String,
    status: json['status'] as String,
  );
}
```

---

## 6. IAuthRemoteDataSource

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart`

```dart
import '../models/user_model.dart';

/// Resultado crudo de /auth/login — el repository decide qué hacer con
/// cada token (dónde persistirlos); el datasource solo parsea la respuesta.
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;
}

abstract class IAuthRemoteDataSource {
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  });
}
```

---

## 7. AuthRemoteDataSourceImpl

**Ruta:** `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart`

```dart
import '../../../../core/network/interfaces/i_network_service.dart';
import '../models/user_model.dart';
import '../interfaces/i_auth_remote_datasource.dart';

/// SOLID (SRP): solo construye el body y parsea la respuesta de
/// /auth/login. Nunca loguea email/password ni los tokens recibidos.
class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({required INetworkService networkService})
    : _networkService = networkService;

  final INetworkService _networkService;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  }) async {
    final response = await _networkService.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        if (deviceFingerprint != null) 'deviceFingerprint': deviceFingerprint,
        if (platform != null) 'platform': platform,
      },
    );
    final map = response as Map<String, dynamic>;
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }
}
```

---

## 8. IAuthLocalDataSource

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_auth_local_datasource.dart`

```dart
/// Persistencia local de la sesión (secure storage). Separado del
/// datasource remoto (regla 5 SOLID — Repository orquesta ambos).
abstract class IAuthLocalDataSource {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> readAccessToken();

  /// Borra solo las claves de auth — nunca deleteAll() (environments-secrets).
  Future<void> clearSession();
}
```

---

## 9. AuthLocalDataSourceImpl

**Ruta:** `lib/features/auth/data/datasources/implementations/auth_local_datasource_impl.dart`

```dart
import '../../../../core/auth/auth_storage_keys.dart';
import '../../../../core/storage/interfaces/i_secure_storage.dart';
import '../interfaces/i_auth_local_datasource.dart';

/// SOLID (SRP): única clase que sabe las claves de storage de la sesión.
class AuthLocalDataSourceImpl implements IAuthLocalDataSource {
  const AuthLocalDataSourceImpl({required ISecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final ISecureStorage _secureStorage;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(AuthStorageKeys.accessToken, accessToken);
    await _secureStorage.write(AuthStorageKeys.refreshToken, refreshToken);
  }

  @override
  Future<String?> readAccessToken() =>
      _secureStorage.read(AuthStorageKeys.accessToken);

  @override
  Future<void> clearSession() => _secureStorage.deleteKeys([
    AuthStorageKeys.accessToken,
    AuthStorageKeys.refreshToken,
  ]);
}
```

---

## 10. AuthRepositoryImpl

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/device/interfaces/i_device_info_provider.dart';
import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/interfaces/i_auth_local_datasource.dart';
import '../datasources/interfaces/i_auth_remote_datasource.dart';

/// SOLID (SRP/DIP): orquesta remoto + local + conectividad; traduce
/// NetworkException → AuthFailure (regla 6 SOLID) — nadie más atrapa
/// excepciones crudas de red para esta feature.
class AuthRepositoryImpl implements IAuthRepository {
  const AuthRepositoryImpl({
    required IAuthRemoteDataSource remoteDataSource,
    required IAuthLocalDataSource localDataSource,
    required INetworkInfo networkInfo,
    required IDeviceInfoProvider deviceInfoProvider,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _networkInfo = networkInfo,
       _deviceInfoProvider = deviceInfoProvider;

  final IAuthRemoteDataSource _remoteDataSource;
  final IAuthLocalDataSource _localDataSource;
  final INetworkInfo _networkInfo;
  final IDeviceInfoProvider _deviceInfoProvider;

  @override
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      final fingerprint = await _deviceInfoProvider.fingerprint();
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
        deviceFingerprint: fingerprint,
        platform: _deviceInfoProvider.platform,
      );
      await _localDataSource.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return Right(result.user);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    }
  }

  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas (no sesión
    // expirada — este repositorio nunca llama endpoints autenticados).
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    if (e.statusCode == 403) {
      if (e.message == 'Email is not verified') {
        return const EmailNotVerifiedFailure();
      }
      if (e.message == 'Account is suspended') {
        return const AccountSuspendedFailure();
      }
    }
    if (e.statusCode == 429) return const TooManyAttemptsFailure();
    return UnknownAuthFailure(e.message);
  }
}
```

---

## 11. AuthStorageKeys

**Ruta:** `lib/core/auth/auth_storage_keys.dart`

```dart
/// Claves de secure storage para la sesión — únicas y compartidas entre
/// AuthLocalDataSourceImpl (escribe/lee) y AuthInterceptor (lee). Evita
/// strings mágicos duplicados entre core/ y features/auth/.
class AuthStorageKeys {
  AuthStorageKeys._();

  static const String accessToken = 'auth_access_token';
  static const String refreshToken = 'auth_refresh_token';
}
```

---

## 12. AuthSession

**Ruta:** `lib/core/auth/auth_session.dart`

```dart
/// SOLID (SRP): único flag en memoria de "¿hay sesión activa en este
/// proceso?". AuthGuard lo lee de forma síncrona (regla 10 SOLID — el
/// guard no puede ser async); la fuente de verdad persistida son los
/// tokens en secure storage (AuthLocalDataSource), esto es solo el
/// reflejo en RAM para no bloquear el redirect de go_router.
/// Restaurar la sesión leyendo el token guardado al abrir la app queda
/// diferido (ver pendientes/ — se resuelve junto con /auth/me).
class AuthSession {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  void markAuthenticated() => _isAuthenticated = true;

  void markLoggedOut() => _isAuthenticated = false;
}
```

---

## 13. IDeviceInfoProvider

**Ruta:** `lib/core/device/interfaces/i_device_info_provider.dart`

```dart
/// Puerto de información del dispositivo — hoy solo lo usa auth
/// (deviceFingerprint/platform de /auth/login), pero vive en core/ porque
/// no es un concepto propio de esa feature.
abstract class IDeviceInfoProvider {
  /// Identificador estable del dispositivo para ligar la sesión
  /// (androidId / identifierForVendor). `null` si no se pudo obtener —
  /// el campo es opcional en el backend.
  Future<String?> fingerprint();

  /// 'android' | 'ios' | null en cualquier otra plataforma.
  String? get platform;
}
```

---

## 14. DeviceInfoProviderImpl

**Ruta:** `lib/core/device/implementations/device_info_provider_impl.dart`

```dart
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../interfaces/i_device_info_provider.dart';

/// SOLID (SRP): única clase que toca device_info_plus/dart:io Platform.
class DeviceInfoProviderImpl implements IDeviceInfoProvider {
  DeviceInfoProviderImpl() : _plugin = DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  Future<String?> fingerprint() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        return info.id; // androidId — ya pseudónimo, MaxLength(255) sobrado
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return info.identifierForVendor; // ID por vendor de Apple
      }
    } catch (_) {
      // Campo opcional en el backend — cualquier fallo de la plataforma
      // no debe bloquear el login.
    }
    return null;
  }

  @override
  String? get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }
}
```

---

## 15. AuthInterceptor

**Ruta:** `lib/core/network/interceptors/auth_interceptor.dart`

```dart
import 'package:dio/dio.dart';

import '../../auth/auth_storage_keys.dart';
import '../../storage/interfaces/i_secure_storage.dart';

/// SOLID (SRP): solo adjunta `Authorization: Bearer <token>` a cada
/// request saliente si hay sesión guardada. El refresh automático al
/// recibir 401 se agrega en el ciclo de integración de /auth/refresh —
/// hasta entonces, un 401 en un endpoint protegido simplemente falla
/// (el caller lo ve como UnauthorizedException).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required ISecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final ISecureStorage _secureStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(AuthStorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

---

## 16. DioNetworkServiceImpl (actualización)

**Ruta:** `lib/core/network/implementations/dio_network_service_impl.dart`

**Antes:**
```dart
class DioNetworkServiceImpl implements INetworkService {
  DioNetworkServiceImpl({required this._logger})
    : _dio = Dio(
        BaseOptions(
          baseUrl: Environment.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    if (Environment.isDev) {
      _dio.interceptors.add(
        // PROVISIONAL: logging de red solo en dev; el AuthInterceptor
        // (bearer + refresh-on-401) se agrega en la propuesta 002-app-auth.
        LogInterceptor(requestBody: false, responseBody: false),
      );
    }
  }
```

**Después:**
```dart
class DioNetworkServiceImpl implements INetworkService {
  DioNetworkServiceImpl({
    required this._logger,
    List<Interceptor> extraInterceptors = const [],
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: Environment.apiBaseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           headers: {'Content-Type': 'application/json'},
         ),
       ) {
    // Interceptores propios de cada feature (ej. AuthInterceptor) primero,
    // para que si el LogInterceptor llegara a reactivar el log de headers
    // más adelante, siga viendo la request ya completa (orden recomendado
    // por la doc de LogInterceptor: "debe ser el último agregado").
    _dio.interceptors.addAll(extraInterceptors);
    if (Environment.isDev) {
      _dio.interceptors.add(
        // SEGURIDAD: requestHeader/responseHeader se fuerzan a false —
        // por defecto Dio los deja en `true`; con el AuthInterceptor
        // mandando "Authorization: Bearer <token>" eso imprimiría el
        // token en la consola de debug. Nunca loguear tokens.
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }
```

---

## 17. setup_di.dart (actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**
```dart
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/interfaces/i_logger_service.dart';
import '../network/implementations/dio_network_service_impl.dart';
import '../network/implementations/network_info_impl.dart';
import '../network/interfaces/i_network_info.dart';
import '../network/interfaces/i_network_service.dart';
import '../routes/app_router.dart';
import '../routes/auth_guard.dart';
import '../storage/implementations/flutter_secure_storage_impl.dart';
import '../storage/interfaces/i_secure_storage.dart';

/// Service Locator (GetIt). Orden de registro por capas:
/// Core Tools → Logging → Storage → Network → DataSources → Repositories
/// → Use Cases → Cubits → Router (flutter-architecture).
final GetIt locator = GetIt.instance;

void setupDI() {
  // --- Logging ---
  // PROVISIONAL: en dart.vm.product también resuelve Debug impl (debugPrint
  // es no-op en release). Crashlytics impl queda en pendientes/003.
  locator.registerLazySingleton<ILoggerService>(
    () => const DebugLoggerServiceImpl(),
  );

  // --- Storage ---
  locator.registerLazySingleton<ISecureStorage>(
    () => FlutterSecureStorageImpl(),
  );

  // --- Network ---
  locator.registerLazySingleton<InternetConnectionChecker>(
    () => InternetConnectionChecker.createInstance(),
  );
  locator.registerLazySingleton<INetworkInfo>(
    () => NetworkInfoImpl(locator<InternetConnectionChecker>()),
  );
  locator.registerLazySingleton<INetworkService>(
    () => DioNetworkServiceImpl(logger: locator<ILoggerService>()),
  );

  // --- Cubits ---
  // PROVISIONAL (presentación): sin use cases reales todavía.
  locator.registerFactory<LoginCubit>(() => LoginCubit());

  // --- Router ---
  // PROVISIONAL: isAuthenticated siempre false — 002-app-auth conecta el
  // AuthCubit.status real (la sesión se lee de ISecureStorage).
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(isAuthenticated: () => false),
  );
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(guard: locator<AuthGuard>()),
  );
}
```

**Después:**
```dart
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/auth/data/datasources/implementations/auth_local_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart';
import '../../features/auth/data/datasources/interfaces/i_auth_local_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/domain/use_cases/login_use_case.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../auth/auth_session.dart';
import '../device/implementations/device_info_provider_impl.dart';
import '../device/interfaces/i_device_info_provider.dart';
import '../logging/implementations/debug_logger_service_impl.dart';
import '../logging/interfaces/i_logger_service.dart';
import '../network/implementations/dio_network_service_impl.dart';
import '../network/implementations/network_info_impl.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../network/interfaces/i_network_info.dart';
import '../network/interfaces/i_network_service.dart';
import '../routes/app_router.dart';
import '../routes/auth_guard.dart';
import '../storage/implementations/flutter_secure_storage_impl.dart';
import '../storage/interfaces/i_secure_storage.dart';

/// Service Locator (GetIt). Orden de registro por capas:
/// Core Tools → Logging → Storage → Network → DataSources → Repositories
/// → Use Cases → Cubits → Router (flutter-architecture).
final GetIt locator = GetIt.instance;

void setupDI() {
  // --- Logging ---
  // PROVISIONAL: en dart.vm.product también resuelve Debug impl (debugPrint
  // es no-op en release). Crashlytics impl queda en pendientes/003.
  locator.registerLazySingleton<ILoggerService>(
    () => const DebugLoggerServiceImpl(),
  );

  // --- Storage ---
  locator.registerLazySingleton<ISecureStorage>(
    () => FlutterSecureStorageImpl(),
  );

  // --- Sesión (flag en memoria — AuthGuard la lee síncrono) ---
  locator.registerLazySingleton<AuthSession>(() => AuthSession());

  // --- Device ---
  locator.registerLazySingleton<IDeviceInfoProvider>(
    () => DeviceInfoProviderImpl(),
  );

  // --- Network ---
  locator.registerLazySingleton<InternetConnectionChecker>(
    () => InternetConnectionChecker.createInstance(),
  );
  locator.registerLazySingleton<INetworkInfo>(
    () => NetworkInfoImpl(locator<InternetConnectionChecker>()),
  );
  locator.registerLazySingleton<INetworkService>(
    () => DioNetworkServiceImpl(
      logger: locator<ILoggerService>(),
      extraInterceptors: [
        AuthInterceptor(secureStorage: locator<ISecureStorage>()),
      ],
    ),
  );

  // --- DataSources (auth) ---
  locator.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(networkService: locator<INetworkService>()),
  );
  locator.registerLazySingleton<IAuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: locator<ISecureStorage>()),
  );

  // --- Repositories (auth) ---
  locator.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: locator<IAuthRemoteDataSource>(),
      localDataSource: locator<IAuthLocalDataSource>(),
      networkInfo: locator<INetworkInfo>(),
      deviceInfoProvider: locator<IDeviceInfoProvider>(),
    ),
  );

  // --- Use Cases (auth) ---
  locator.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(locator<IAuthRepository>()),
  );

  // --- Cubits ---
  locator.registerFactory<LoginCubit>(
    () => LoginCubit(
      loginUseCase: locator<LoginUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );

  // --- Router ---
  // AuthGuard lee la sesión real en memoria — login la marca al tener
  // éxito; restaurarla leyendo el token guardado al abrir la app queda
  // diferido (pendientes/ — junto con /auth/me).
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(isAuthenticated: () => locator<AuthSession>().isAuthenticated),
  );
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(guard: locator<AuthGuard>()),
  );
}
```

---

## 18. LoginState (actualización)

**Ruta:** `lib/features/auth/presentation/cubit/login_state.dart`

**Antes:**
```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../inputs/login_inputs.dart';

enum LoginStatus { initial, inProgress, success, failure }
```
```dart
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailInput.pure(),
    this.password = const PasswordInput.pure(),
    this.obscurePassword = true,
    this.status = LoginStatus.initial,
    this.showEmailError = false,
    this.showPasswordError = false,
    this.rememberMe = false,
  });

  final EmailInput email;
  final PasswordInput password;
  final bool obscurePassword;
  final LoginStatus status;
  final bool showEmailError;
  final bool showPasswordError;

  /// En la integración decidirá si el refresh token persiste entre
  /// sesiones (secure storage) o la sesión muere al cerrar la app.
  final bool rememberMe;
```
```dart
  LoginState copyWith({
    EmailInput? email,
    PasswordInput? password,
    bool? obscurePassword,
    LoginStatus? status,
    bool? showEmailError,
    bool? showPasswordError,
    bool? rememberMe,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      showEmailError: showEmailError ?? this.showEmailError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    obscurePassword,
    status,
    showEmailError,
    showPasswordError,
    rememberMe,
  ];
}
```

**Después:**
```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../domain/failures/auth_failure.dart';
import '../inputs/login_inputs.dart';

/// `failure` = validación local (campos vacíos/inválidos) — ya existía.
/// `authError` = el backend rechazó el login (credenciales, cuenta, rate
/// limit, sin conexión) — nuevo, trae `authFailure` con el motivo exacto.
enum LoginStatus { initial, inProgress, success, failure, authError }
```
```dart
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailInput.pure(),
    this.password = const PasswordInput.pure(),
    this.obscurePassword = true,
    this.status = LoginStatus.initial,
    this.showEmailError = false,
    this.showPasswordError = false,
    this.rememberMe = false,
    this.authFailure,
  });

  final EmailInput email;
  final PasswordInput password;
  final bool obscurePassword;
  final LoginStatus status;
  final bool showEmailError;
  final bool showPasswordError;

  /// Reservado a futuro (ej. recordar el correo) — la sesión siempre
  /// persiste en secure storage independientemente de este flag.
  final bool rememberMe;

  /// Solo tiene valor cuando status == authError.
  final AuthFailure? authFailure;
```
```dart
  LoginState copyWith({
    EmailInput? email,
    PasswordInput? password,
    bool? obscurePassword,
    LoginStatus? status,
    bool? showEmailError,
    bool? showPasswordError,
    bool? rememberMe,
    AuthFailure? authFailure,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      showEmailError: showEmailError ?? this.showEmailError,
      showPasswordError: showPasswordError ?? this.showPasswordError,
      rememberMe: rememberMe ?? this.rememberMe,
      // authFailure se limpia explícitamente pasando el nuevo status,
      // nunca se arrastra entre intentos (null por defecto en cada submit).
      authFailure: status == LoginStatus.authError
          ? (authFailure ?? this.authFailure)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    obscurePassword,
    status,
    showEmailError,
    showPasswordError,
    rememberMe,
    authFailure,
  ];
}
```

---

## 19. LoginCubit (actualización)

**Ruta:** `lib/features/auth/presentation/cubit/login_cubit.dart`

**Antes:**
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/login_inputs.dart';
import 'login_state.dart';

/// PROVISIONAL (fase presentación): el submit simula la llamada al backend
/// con un delay y emite `success` — la integración real de /auth/login
/// reemplaza este método en la propuesta de integración.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());
```
```dart
  /// Re-sanitiza el email por si algo quedó sin pasar por `onChanged`
  /// (paste largo, autofill del sistema) antes de validar.
  Future<void> submit() async {
    if (state.isInProgress) return; // doble tap / tap + done del teclado
    emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
    if (!state.isValid) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          showEmailError: true,
          showPasswordError: true,
        ),
      );
      emit(state.copyWith(status: LoginStatus.initial));
      return;
    }
    emit(state.copyWith(status: LoginStatus.inProgress));
    // PROVISIONAL: sin endpoint todavía — delay para mostrar el loading.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (isClosed) return;
    emit(state.copyWith(status: LoginStatus.success));
  }
}
```

**Después:**
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/use_cases/login_use_case.dart';
import '../inputs/login_inputs.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required LoginUseCase loginUseCase, required AuthSession authSession})
    : _loginUseCase = loginUseCase,
      _authSession = authSession,
      super(const LoginState());

  final LoginUseCase _loginUseCase;
  final AuthSession _authSession;
```
```dart
  /// Re-sanitiza el email por si algo quedó sin pasar por `onChanged`
  /// (paste largo, autofill del sistema) antes de validar.
  Future<void> submit() async {
    if (state.isInProgress) return; // doble tap / tap + done del teclado
    emit(state.copyWith(email: EmailInput.dirty(state.email.value.trim())));
    if (!state.isValid) {
      emit(
        state.copyWith(
          status: LoginStatus.failure,
          showEmailError: true,
          showPasswordError: true,
        ),
      );
      emit(state.copyWith(status: LoginStatus.initial));
      return;
    }
    emit(state.copyWith(status: LoginStatus.inProgress));
    final result = await _loginUseCase(
      email: state.email.value,
      password: state.password.value,
    );
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(state.copyWith(status: LoginStatus.authError, authFailure: failure));
        emit(state.copyWith(status: LoginStatus.initial));
      },
      (_) {
        _authSession.markAuthenticated();
        emit(state.copyWith(status: LoginStatus.success));
      },
    );
  }
}
```

---

## 20. LoginScreen (actualización)

**Ruta:** `lib/features/auth/presentation/screens/login_screen.dart`

**Antes:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_form_fields.dart';
```
```dart
  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit();
  }
```
```dart
          listener: (context, state) {
            if (state.status == LoginStatus.success) {
              TextInput.finishAutofillContext(shouldSave: true);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.loginDemoSuccess)));
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.loginFormInvalid),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
```

**Después:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/failures/auth_failure.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_form_fields.dart';
```
```dart
  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit();
  }

  /// La UI nunca muestra el texto crudo del backend — cada AuthFailure
  /// mapea a su copy en español (i18n-workflow).
  String _authErrorMessage(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure) {
        InvalidCredentialsFailure() => l10n.loginErrorInvalidCredentials,
        EmailNotVerifiedFailure() => l10n.loginErrorEmailNotVerified,
        AccountSuspendedFailure() => l10n.loginErrorAccountSuspended,
        TooManyAttemptsFailure() => l10n.loginErrorTooManyAttempts,
        NoConnectionFailure() => l10n.loginErrorNoConnection,
        UnknownAuthFailure() => l10n.loginErrorGeneric,
      };
```
```dart
          listener: (context, state) {
            if (state.status == LoginStatus.success) {
              TextInput.finishAutofillContext(shouldSave: true);
              context.go(AuthGuard.homeRoute);
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.loginFormInvalid),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            } else if (state.status == LoginStatus.authError &&
                state.authFailure != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_authErrorMessage(l10n, state.authFailure!)),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
```

---

## 21. app_es.arb (actualización)

**Ruta:** `lib/l10n/app_es.arb`

**Antes:**
```json
  "loginDemoSuccess": "Inicio de sesión simulado — sin backend todavía",
  "comingSoon": "Disponible próximamente"
```

**Después:**
```json
  "loginErrorInvalidCredentials": "Correo o contraseña incorrectos",
  "loginErrorEmailNotVerified": "Verifica tu correo antes de iniciar sesión",
  "loginErrorAccountSuspended": "Tu cuenta está suspendida",
  "loginErrorTooManyAttempts": "Demasiados intentos — espera un momento",
  "loginErrorNoConnection": "Sin conexión a internet",
  "loginErrorGeneric": "No se pudo iniciar sesión, intenta de nuevo",
  "comingSoon": "Disponible próximamente"
```

Ejecutar `flutter gen-l10n` después de este cambio (nunca escribir a mano
`app_localizations*.dart`).

---

## 22. Pendiente — restaurar sesión al abrir la app

**Ruta:** `pendientes/004-restaurar-sesion.md` (nuevo, formato de `pendientes-produccion`)

```markdown
# Pendiente: Restaurar sesión al abrir la app

> **Estado: 🟡 DIFERIDO** — decisión explícita del usuario (propuesta 004)
> **Producto:** frontend
> **Bloqueo:** no bloquea producción del login; si se lanza así, cada
> apertura de la app pide login aunque haya sesión guardada

## Contexto

Hoy `AuthSession` nace siempre en `false` en cada arranque de proceso — el
splash no revisa si ya hay un `accessToken` guardado en secure storage.
Resultado: cerrar y volver a abrir la app siempre manda a `/login`, aunque
el usuario inició sesión minutos antes.

## Por qué no se resolvió ya

Restaurarla "bien" implica validar el token contra el backend (no solo
comprobar que el archivo existe) — un token guardado puede estar vencido
o revocado (logout desde otro dispositivo). Esa validación es
`GET /auth/me`, que todavía no se integra (es su propio ciclo).

## Qué falta

- Integrar `/auth/me` (propio ciclo, screen-first-workflow).
- En el splash: si hay `accessToken` guardado, llamar a `/auth/me`;
  200 → `AuthSession.markAuthenticated()` + ir a `/home`; 401 → limpiar la
  sesión local y seguir a `/login`.

## Criterio de cierre

- Cerrar y reabrir la app con sesión previa válida lleva a `/home` sin
  pedir login de nuevo.
- Un token vencido/revocado limpia la sesión local y pide login.
```

---

## Orden de aplicación

1. `flutter pub add device_info_plus`
2. `lib/core/auth/auth_storage_keys.dart`
3. `lib/core/auth/auth_session.dart`
4. `lib/core/device/interfaces/i_device_info_provider.dart`
5. `lib/core/device/implementations/device_info_provider_impl.dart`
6. `lib/core/network/interceptors/auth_interceptor.dart`
7. `lib/core/network/implementations/dio_network_service_impl.dart` (actualizar)
8. `lib/features/auth/domain/entities/user.dart`
9. `lib/features/auth/domain/failures/auth_failure.dart`
10. `lib/features/auth/domain/repositories/i_auth_repository.dart`
11. `lib/features/auth/domain/use_cases/login_use_case.dart`
12. `lib/features/auth/data/models/user_model.dart`
13. `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart`
14. `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart`
15. `lib/features/auth/data/datasources/interfaces/i_auth_local_datasource.dart`
16. `lib/features/auth/data/datasources/implementations/auth_local_datasource_impl.dart`
17. `lib/features/auth/data/repositories/auth_repository_impl.dart`
18. `lib/core/di/setup_di.dart` (actualizar)
19. `lib/features/auth/presentation/cubit/login_state.dart` (actualizar)
20. `lib/features/auth/presentation/cubit/login_cubit.dart` (actualizar)
21. `lib/l10n/app_es.arb` (actualizar) + `flutter gen-l10n`
22. `lib/features/auth/presentation/screens/login_screen.dart` (actualizar)
23. `pendientes/004-restaurar-sesion.md`
24. Tests (ver siguiente sección) + `flutter analyze` + `flutter test`
25. Verificación manual contra el backend real (`pcalientes_backend` en `:3000`)

## Tests a agregar (testing-workflow)

- `test/features/auth/data/repositories/auth_repository_impl_test.dart` — mockea
  `IAuthRemoteDataSource`/`IAuthLocalDataSource`/`INetworkInfo`/`IDeviceInfoProvider`;
  casos: éxito guarda sesión, sin conexión, 401→InvalidCredentials, 403 ambos
  mensajes, 429, error desconocido.
- `test/features/auth/domain/use_cases/login_use_case_test.dart` — passthrough simple.
- `test/features/auth/presentation/cubit/login_cubit_test.dart` — actualizar los
  tests existentes de `submit()` (ya no hay delay fijo) + nuevos casos con
  `LoginUseCase` mockeado devolviendo `Left`/`Right` → estados `authError`/`success`.
- `test/core/network/interceptors/auth_interceptor_test.dart` — adjunta el header
  solo si hay token guardado.
