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
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
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
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(email: email),
  );

  // --- Router ---
  // AuthGuard lee la sesión real en memoria — login la marca al tener
  // éxito; restaurarla leyendo el token guardado al abrir la app queda
  // diferido (pendientes/ — junto con /auth/me).
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(
      isAuthenticated: () => locator<AuthSession>().isAuthenticated,
    ),
  );
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(guard: locator<AuthGuard>()),
  );
}
