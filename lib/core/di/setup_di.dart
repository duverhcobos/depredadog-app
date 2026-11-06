import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/auth/data/datasources/implementations/auth_local_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart';
import '../../features/auth/data/datasources/implementations/google_sign_in_gateway_impl.dart';
import '../../features/auth/data/datasources/interfaces/i_auth_local_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart';
import '../../features/auth/data/datasources/interfaces/i_google_sign_in_gateway.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/domain/use_cases/check_reset_code_use_case.dart';
import '../../features/auth/domain/use_cases/forgot_password_use_case.dart';
import '../../features/auth/domain/use_cases/google_sign_in_use_case.dart';
import '../../features/auth/domain/use_cases/login_use_case.dart';
import '../../features/auth/domain/use_cases/register_use_case.dart';
import '../../features/auth/domain/use_cases/resend_verification_use_case.dart';
import '../../features/auth/domain/use_cases/reset_password_use_case.dart';
import '../../features/auth/domain/use_cases/restore_session_use_case.dart';
import '../../features/auth/domain/use_cases/verify_email_use_case.dart';
import '../../features/auth/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/auth/presentation/cubit/splash_cubit.dart';
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/home/data/datasources/implementations/catalog_remote_datasource_impl.dart';
import '../../features/home/data/datasources/interfaces/i_catalog_remote_datasource.dart';
import '../../features/home/data/repositories/catalog_repository_impl.dart';
import '../../features/home/domain/repositories/i_catalog_repository.dart';
import '../../features/home/domain/use_cases/get_catalog_menu_use_case.dart';
import '../../features/home/presentation/cubit/catalog_cubit.dart';
import '../auth/auth_session.dart';
import '../auth/token_refresh_service.dart';
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
  // TokenRefreshService (propuesta 015): único que conoce POST
  // /auth/refresh y la persistencia del par de tokens — single-flight
  // interno deduplica 401s concurrentes.
  locator.registerLazySingleton<TokenRefreshService>(
    () => TokenRefreshService(
      networkService: locator<INetworkService>(),
      secureStorage: locator<ISecureStorage>(),
      session: locator<AuthSession>(),
      logger: locator<ILoggerService>(),
    ),
  );
  // AuthInterceptor se construye dentro de la factory de
  // DioNetworkServiceImpl — sus dependencias de red son RESOLVERS
  // diferidos, no instancias: resolver TokenRefreshService acá
  // re-entraría a INetworkService → impl con su factory aún en curso
  // (get_it aborta con "circular dependency"). Se resuelven al primer
  // 401, cuando el grafo ya existe.
  locator.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(
      secureStorage: locator<ISecureStorage>(),
      refresherResolver: () => locator<TokenRefreshService>(),
      dioResolver: () => locator<DioNetworkServiceImpl>().dio,
    ),
  );
  // El impl va tipado además del alias INetworkService: el dioResolver
  // del interceptor y la app entera comparten UNA sola instancia de Dio
  // (un solo interceptor chain).
  locator.registerLazySingleton<DioNetworkServiceImpl>(
    () => DioNetworkServiceImpl(
      logger: locator<ILoggerService>(),
      extraInterceptors: [locator<AuthInterceptor>()],
    ),
  );
  locator.registerLazySingleton<INetworkService>(
    () => locator<DioNetworkServiceImpl>(),
  );

  // --- DataSources (auth) ---
  locator.registerLazySingleton<IAuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(networkService: locator<INetworkService>()),
  );
  locator.registerLazySingleton<IAuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: locator<ISecureStorage>()),
  );
  // Gateway del SDK de Google (no es HTTP — envuelve el plugin; init lazy
  // al primer tap, propuesta 014).
  locator.registerLazySingleton<IGoogleSignInGateway>(
    () => GoogleSignInGatewayImpl(),
  );

  // --- Repositories (auth) ---
  locator.registerLazySingleton<IAuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: locator<IAuthRemoteDataSource>(),
      localDataSource: locator<IAuthLocalDataSource>(),
      networkInfo: locator<INetworkInfo>(),
      deviceInfoProvider: locator<IDeviceInfoProvider>(),
      googleGateway: locator<IGoogleSignInGateway>(),
    ),
  );

  // --- Catálogo (propuesta 019) ---
  locator.registerLazySingleton<ICatalogRemoteDataSource>(
    () =>
        CatalogRemoteDataSourceImpl(networkService: locator<INetworkService>()),
  );
  locator.registerLazySingleton<ICatalogRepository>(
    () => CatalogRepositoryImpl(
      remoteDataSource: locator<ICatalogRemoteDataSource>(),
      networkInfo: locator<INetworkInfo>(),
    ),
  );
  locator.registerLazySingleton<GetCatalogMenuUseCase>(
    () => GetCatalogMenuUseCase(locator<ICatalogRepository>()),
  );
  // lazySingleton (regla 9 SOLID): el menú es estado persistente
  // compartido entre las 3 pantallas — una sola instancia.
  locator.registerLazySingleton<CatalogCubit>(
    () => CatalogCubit(
      getCatalogMenuUseCase: locator<GetCatalogMenuUseCase>(),
      logger: locator<ILoggerService>(),
    ),
  );

  // --- Carrito (propuesta 020): lazySingleton — estado compartido
  // entre badge, pantalla y checkout futuro; una sola instancia.
  // En memoria: no persiste entre arranques (decisión MVP).
  locator.registerLazySingleton<CartCubit>(() => CartCubit());

  // --- Use Cases (auth) ---
  locator.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<VerifyEmailUseCase>(
    () => VerifyEmailUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<ResendVerificationUseCase>(
    () => ResendVerificationUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<RestoreSessionUseCase>(
    () => RestoreSessionUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<ForgotPasswordUseCase>(
    () => ForgotPasswordUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<CheckResetCodeUseCase>(
    () => CheckResetCodeUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<GoogleSignInUseCase>(
    () => GoogleSignInUseCase(locator<IAuthRepository>()),
  );

  // --- Cubits ---
  locator.registerFactory<SplashCubit>(
    () => SplashCubit(
      restoreSessionUseCase: locator<RestoreSessionUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
  locator.registerFactory<LoginCubit>(
    () => LoginCubit(
      loginUseCase: locator<LoginUseCase>(),
      googleSignInUseCase: locator<GoogleSignInUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
  // RegisterCubit recibe AuthSession SOLO por el flujo Google (propuesta
  // 014): el registro por email sigue sin autenticar — su auto-login
  // ocurre en verify-email (propuesta 010); la sesión Google nace
  // completa y marca el flag en memoria para que el guard deje pasar
  // a /home.
  locator.registerFactory<RegisterCubit>(
    () => RegisterCubit(
      registerUseCase: locator<RegisterUseCase>(),
      googleSignInUseCase: locator<GoogleSignInUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
  // ForgotPasswordCubit (integración §012): el reset emite IssuedSession
  // igual que verifyEmail — recibe los 3 use cases del flujo + AuthSession
  // para el auto-login en memoria (guard → /home).
  locator.registerFactory<ForgotPasswordCubit>(
    () => ForgotPasswordCubit(
      forgotPasswordUseCase: locator<ForgotPasswordUseCase>(),
      checkResetCodeUseCase: locator<CheckResetCodeUseCase>(),
      resetPasswordUseCase: locator<ResetPasswordUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(
      email: email,
      verifyEmailUseCase: locator<VerifyEmailUseCase>(),
      resendVerificationUseCase: locator<ResendVerificationUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );

  // --- Router ---
  // AuthGuard lee la sesión real en memoria — login/verify la marcan al
  // tener éxito y el splash la restaura vía /auth/me al abrir la app.
  locator.registerLazySingleton<AuthGuard>(
    () => AuthGuard(
      isAuthenticated: () => locator<AuthSession>().isAuthenticated,
    ),
  );
  locator.registerLazySingleton<AppRouter>(
    () => AppRouter(guard: locator<AuthGuard>()),
  );
}
