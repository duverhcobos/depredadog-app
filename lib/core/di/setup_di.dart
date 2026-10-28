import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
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
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(email: email),
  );

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
