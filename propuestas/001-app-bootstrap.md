# Propuesta: Bootstrap de la app — core transversal (environment, logging, network, storage, DI, router, theme, i18n)

Infraestructura base de **depredadog_app** siguiendo `flutter-architecture`,
`solid-clean-architecture`, `environments-secrets`, `navigation-routing`,
`i18n-workflow` y `ui-design-standard`. Sin lógica de negocio de features —
la feature `auth` entra en la propuesta `002-app-auth` sobre este core.

Alcance visual: la app corre y muestra **Splash → Welcome** (placeholder
temporal hasta 002). La ruta `/home` existe pero el guard la bloquea sin
sesión — demuestra que la protección funciona desde ya.

---

## Decisiones de diseño (ya validadas)

- **Stack**: el definido en `flutter-architecture` — `flutter_bloc` (Cubits),
  `get_it`, `dio`, `go_router`, `flutter_secure_storage`,
  `internet_connection_checker`, `equatable`, `dartz`, `formz`,
  `flutter_localizations` + `intl`. Tests: `bloc_test`, `mocktail`.
- **Un solo idioma: `es`** — `I18N_GUIDE.md` ya lo fija ("el producto tiene un
  solo idioma"). No se crea `LocaleCubit` hasta que exista un segundo `.arb`.
- **AuthGuard sin AuthCubit aún**: el guard recibe `isAuthenticated` por
  constructor (DIP — regla 10 de SOLID); el bootstrap lo cablea a
  `() => false` marcado `// PROVISIONAL` hasta que 002 conecte `AuthCubit`.
- **Logger en prod**: existe solo `DebugLoggerServiceImpl`; en `dart.vm.product`
  se usa el mismo impl (`debugPrint` es no-op en release) con comentario
  `// PROVISIONAL` — Crashlytics queda como pendiente documentado.
- **Auth interceptor**: el `INetworkService` acepta interceptores; el
  `AuthInterceptor` (adjunta bearer + refresh-on-401) llega en 002 junto a
  los tokens que consume. El bootstrap solo deja el enchufe.
- **Paleta Depredadog** (definida por el usuario): rojo ketchup `#D62828`
  (marca/botones), amarillo mostaza `#FBBF24` (promos/precios), crema pan
  `#FFF3D6` (fondo), marrón parrilla `#4A2511` (títulos/nav), verde
  pepinillo `#5B8C3A` (extras/disponible). Variantes dark derivadas de la
  misma familia — hex exactos en la sección de theme.
- **Pantallas placeholder**: `SplashScreen` y `WelcomeScreen` viven en
  `lib/core/screens/` (no son features); `WelcomeScreen` se reemplaza por el
  flujo real de auth en 002.

## Desviaciones del modelo/skills

- `flutter-architecture` no lista `lib/core/storage/` explícitamente — se crea
  `lib/core/storage/` para el puerto de almacenamiento seguro (equivalente al
  "datasource de sesión segura" que menciona `environments-secrets`).
- `navigation-routing` documenta `go_router ^18` — se instala la última
  estable compatible vía `flutter pub add` (la restricción real queda en
  `pubspec.yaml`).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | 10 dependencias + 2 dev + `generate: true` (l10n) |
| `l10n.yaml` | Nuevo — config gen-l10n (`synthetic-package: false`) |
| `lib/l10n/app_es.arb` | Nuevo — diccionario español |
| `lib/main.dart` | Reescrito — ultraligero, llama `AppBootstrap.run` |
| `lib/app.dart` | Nuevo — `DepredadogApp` (MaterialApp.router) |
| `lib/core/bootstrap/app_bootstrap.dart` | Nuevo — orquesta arranque |
| `lib/core/constants/environment/environment.dart` | Nuevo — dart-defines |
| `lib/core/logging/{interfaces,implementations}/` | Nuevo — ILoggerService + Debug impl |
| `lib/core/network/...` | Nuevo — INetworkService/Dio impl, INetworkInfo, excepciones |
| `lib/core/storage/...` | Nuevo — ISecureStorage + FlutterSecureStorage impl |
| `lib/core/routes/{app_router,auth_guard,custom_transitions}.dart` | Nuevo |
| `lib/core/theme/{app_colors,app_theme}.dart` | Nuevo — paleta M3 light/dark |
| `lib/core/widgets/app_backdrop.dart` | Nuevo — backdrop de marca |
| `lib/core/screens/{splash_screen,welcome_screen}.dart` | Nuevo — placeholder |
| `lib/core/di/setup_di.dart` | Nuevo — registro get_it por capas |
| `android/app/build.gradle.kts` | `minSdk = 23` (flutter_secure_storage) |
| `test/widget_test.dart` | Reemplazado por tests del core |
| `test/core/routes/auth_guard_test.dart` | Nuevo |
| `test/core/constants/environment_test.dart` | Nuevo |
| `test/core/screens/welcome_screen_test.dart` | Nuevo |
| `Design/design-system.yaml` | Bump 1.1.0 — paleta real + specs backdrop/splash/welcome |
| `../pcalientes_backend/pendientes/003-crashlytics-app.md` | Nuevo — logger de prod pendiente |

---

## 1. `pubspec.yaml` (archivo existente — actualización)

**Antes:**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
```

**Después** (versiones exactas las resuelve `flutter pub add`; restricciones
mínimas indicadas):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  cupertino_icons: ^1.0.8
  dio: ^5.9.0
  flutter_bloc: ^9.1.0
  get_it: ^8.2.0
  go_router: ^16.0.0
  flutter_secure_storage: ^10.0.0
  internet_connection_checker: ^3.0.1
  equatable: ^2.0.7
  dartz: ^0.10.1
  formz: ^0.8.0
  intl: ^0.20.2
```

`dev_dependencies` — agregar:

```yaml
  bloc_test: ^10.0.0
  mocktail: ^1.0.4
```

Y en la sección `flutter:` — agregar `generate: true` (habilita gen-l10n):

**Antes:**

```yaml
flutter:
  uses-material-design: true
```

**Después:**

```yaml
flutter:
  generate: true
  uses-material-design: true
```

Comando del implementador: `flutter pub add` por paquete (resuelve la última
estable compatible con Dart 3.13 y escribe la restricción real).

## 2. `l10n.yaml` (archivo nuevo)

```yaml
arb-dir: lib/l10n
template-arb-file: app_es.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
```

## 3. `lib/l10n/app_es.arb` (archivo nuevo)

```json
{
  "@@locale": "es",
  "appName": "Depredadog",
  "splashTagline": "Comida rápida, caliente de verdad",
  "welcomeTitle": "Bienvenido a Depredadog",
  "welcomeBody": "La autenticación llega en la próxima iteración. Esta pantalla es temporal.",
  "welcomeAuthPending": "Acceso disponible muy pronto"
}
```

Tras crear el archivo: **ejecutar `flutter gen-l10n`** (genera
`lib/l10n/app_localizations*.dart` — no editarlos a mano).

## 4. `lib/core/constants/environment/environment.dart` (archivo nuevo)

```dart
/// Emisor único de configuración de entorno (ver ENVIRONMENTS.md).
/// Toda variable externa entra por --dart-define y se centraliza aquí;
/// ningún otro archivo lee variables de entorno directamente.
enum EnvType { dev, stg, prod }

class Environment {
  Environment._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static const EnvType currentEnvironment = switch (_env) {
    'stg' => EnvType.stg,
    'prod' => EnvType.prod,
    _ => EnvType.dev,
  };

  /// Base URL del backend. En dev con emulador Android, 10.0.2.2 = localhost
  /// del host. En dispositivo físico: --dart-define=API_BASE_URL=http://<ip-lan>:3000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const bool isDev = currentEnvironment == EnvType.dev;
  static const bool isProd = currentEnvironment == EnvType.prod;
}
```

## 5. `lib/core/logging/interfaces/i_logger_service.dart` (archivo nuevo)

```dart
/// Puerto de logging de la app (DIP). Nunca usar print() — regla 12 SOLID.
/// Prohibido loguear tokens, contraseñas ni cuerpos de request/response.
abstract class ILoggerService {
  void debug(String message, {String? tag});
  void info(String message, {String? tag});
  void warning(String message, {String? tag});
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag});
}
```

## 6. `lib/core/logging/implementations/debug_logger_service_impl.dart` (archivo nuevo)

```dart
import 'package:flutter/foundation.dart';
import '../interfaces/i_logger_service.dart';

/// Logger de desarrollo: imprime con debugPrint (no-op en release).
class DebugLoggerServiceImpl implements ILoggerService {
  const DebugLoggerServiceImpl();

  @override
  void debug(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} DEBUG] $message');
  }

  @override
  void info(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} INFO] $message');
  }

  @override
  void warning(String message, {String? tag}) {
    debugPrint('[${_tag(tag)} WARN] $message');
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    debugPrint('[${_tag(tag)} ERROR] $message');
    if (error != null) debugPrint('  → $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  static String _tag(String? tag) => tag ?? 'Depredadog';
}
```

## 7. `lib/core/network/interfaces/i_network_info.dart` (archivo nuevo)

```dart
/// Puerto de conectividad. Los repositories lo consultan antes de llamadas
/// remotas (regla 5 SOLID — el impl concreto es intercambiable).
abstract class INetworkInfo {
  Future<bool> get isConnected;
}
```

## 8. `lib/core/network/implementations/network_info_impl.dart` (archivo nuevo)

```dart
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../interfaces/i_network_info.dart';

class NetworkInfoImpl implements INetworkInfo {
  const NetworkInfoImpl(this._checker);

  final InternetConnectionChecker _checker;

  @override
  Future<bool> get isConnected => _checker.hasConnection;
}
```

## 9. `lib/core/network/exceptions/network_exception.dart` (archivo nuevo)

```dart
/// Excepciones de infraestructura de red. Los repositories las mapean a
/// Failure de dominio (regla 6 SOLID) — la UI nunca las ve.
sealed class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

/// Sin conectividad detectada por INetworkInfo antes de la llamada.
class NoConnectionException extends NetworkException {
  const NoConnectionException() : super('No internet connection');
}

/// El servidor respondió con error (4xx/5xx) o timeout.
class ServerException extends NetworkException {
  const ServerException(super.message, {super.statusCode});
}

/// Respuesta 401 — la sesión expiró o el token es inválido.
/// (La feature auth la usa para forzar logout/refresh.)
class UnauthorizedException extends NetworkException {
  const UnauthorizedException() : super('Unauthorized', statusCode: 401);
}
```

## 10. `lib/core/network/interfaces/i_network_service.dart` (archivo nuevo)

```dart
/// Puerto HTTP de la app. Devuelve el body decodificado o lanza
/// NetworkException — los callers nunca ven DioException.
abstract class INetworkService {
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers});

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  Future<dynamic> delete(String path, {Map<String, String>? headers});
}
```

## 11. `lib/core/network/implementations/dio_network_service_impl.dart` (archivo nuevo)

```dart
import 'package:dio/dio.dart';
import '../../constants/environment/environment.dart';
import '../../logging/interfaces/i_logger_service.dart';
import '../exceptions/network_exception.dart';
import '../interfaces/i_network_service.dart';

/// Implementación Dio del puerto HTTP. Centraliza baseUrl, timeouts,
/// mapeo DioException → NetworkException y logging de requests en dev.
class DioNetworkServiceImpl implements INetworkService {
  DioNetworkServiceImpl({required ILoggerService logger})
      : _logger = logger,
        _dio = Dio(
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

  final Dio _dio;
  final ILoggerService _logger;

  /// Expone el Dio para que futuras capas (002-auth) agreguen interceptores
  /// sin reemplazar el servicio.
  Dio get client => _dio;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) =>
      _request(
        () => _dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          options: _opts(headers),
        ),
      );

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request(() => _dio.post<dynamic>(path, data: body, options: _opts(headers)));

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request(() => _dio.put<dynamic>(path, data: body, options: _opts(headers)));

  @override
  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request(() => _dio.patch<dynamic>(path, data: body, options: _opts(headers)));

  @override
  Future<dynamic> delete(String path, {Map<String, String>? headers}) =>
      _request(() => _dio.delete<dynamic>(path, options: _opts(headers)));

  Options? _opts(Map<String, String>? headers) =>
      headers == null ? null : Options(headers: headers);

  Future<dynamic> _request(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  NetworkException _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return const UnauthorizedException();
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NoConnectionException();
    }
    final serverMessage = e.response?.data is Map<String, dynamic>
        ? (e.response!.data as Map<String, dynamic>)['message']
        : null;
    _logger.warning(
      'HTTP ${e.requestOptions.method} ${e.requestOptions.path} → $status',
      tag: 'Network',
    );
    return ServerException(
      serverMessage is String
          ? serverMessage
          : (serverMessage is List && serverMessage.isNotEmpty
              ? serverMessage.first.toString()
              : 'Request failed'),
      statusCode: status,
    );
  }
}
```

## 12. `lib/core/storage/interfaces/i_secure_storage.dart` (archivo nuevo)

```dart
/// Puerto de almacenamiento seguro (keychain/keystore). La feature auth lo
/// usa para tokens; nunca deleteAll() salvo intención explícita — borrar
/// solo claves propias (environments-secrets).
abstract class ISecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteKeys(List<String> keys);
}
```

## 13. `lib/core/storage/implementations/flutter_secure_storage_impl.dart` (archivo nuevo)

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../interfaces/i_secure_storage.dart';

class FlutterSecureStorageImpl implements ISecureStorage {
  FlutterSecureStorageImpl()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteKeys(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }
}
```

## 14. `lib/core/routes/auth_guard.dart` (archivo nuevo)

```dart
/// Guardia de rutas — lógica de protección aislada del framework de routing
/// (regla 10 SOLID): recibe `isAuthenticated` y el `location` como String,
/// nunca GoRouterState, para que sea testeable y portable.
///
/// Las constantes de ruta completas viven AQUÍ (navigation-routing):
/// la UI navega siempre con estas constantes, nunca con strings sueltos.
class AuthGuard {
  const AuthGuard({
    required bool Function() isAuthenticated,
    Set<String>? publicRoutes,
  })  : _isAuthenticated = isAuthenticated,
        _publicRoutes = publicRoutes ?? defaultPublicRoutes;

  final bool Function() _isAuthenticated;
  final Set<String> _publicRoutes;

  // ---- Rutas (constantes públicas, siempre completas) ----
  static const String splashRoute = '/';
  static const String welcomeRoute = '/welcome';
  static const String homeRoute = '/home';

  // Rutas de la feature auth (002) — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';

  /// Rutas accesibles sin sesión.
  static const Set<String> defaultPublicRoutes = {
    splashRoute,
    welcomeRoute,
    loginRoute,
    registerRoute,
    verifyEmailRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
  };

  /// A dónde mandar a un usuario sin sesión que pide una ruta protegida.
  static const String unauthenticatedRedirect = welcomeRoute;

  /// A dónde mandar a un usuario con sesión que pide una ruta de auth.
  static const String authenticatedRedirect = homeRoute;

  /// Devuelve la ruta de redirect o `null` si el acceso es válido.
  String? redirect(String location) {
    final isPublic = _publicRoutes.any(
      (r) => location == r || location.startsWith('$r/'),
    );
    final authed = _isAuthenticated();

    if (!authed && !isPublic) return unauthenticatedRedirect;
    if (authed && isPublic && location != splashRoute) {
      return authenticatedRedirect;
    }
    return null;
  }
}
```

## 15. `lib/core/routes/custom_transitions.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page builders de la casa — nada de MaterialPageRoute suelto.
/// `fade` para transiciones neutras (splash), `slideUp` para flujos que se
/// sienten modales (login, forgot-password).
class CustomTransitions {
  CustomTransitions._();

  static Page<void> fade(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  static Page<void> slideUp(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
```

## 16. `lib/core/routes/app_router.dart` (archivo nuevo)

```dart
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import 'auth_guard.dart';
import 'custom_transitions.dart';

/// Declaración de rutas. Las constantes viven en AuthGuard; los GoRoute
/// hijos usan segmentos RELATIVOS (navigation-routing).
/// NOTA: el GoRouter se construye una vez — tras tocar este archivo hace
/// falta hot RESTART, no reload.
class AppRouter {
  AppRouter({required AuthGuard guard}) : _guard = guard;

  final AuthGuard _guard;

  late final GoRouter router = GoRouter(
    initialLocation: AuthGuard.splashRoute,
    redirect: (context, state) => _guard.redirect(state.matchedLocation),
    routes: [
      GoRoute(
        path: AuthGuard.splashRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: AuthGuard.welcomeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // /home es el destino autenticado — pantalla real llega con las
      // features; por ahora el guard bloquea el acceso sin sesión.
      // PROVISIONAL: placeholder hasta que 002-app-auth/defina el shell.
      GoRoute(
        path: AuthGuard.homeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // Las rutas /login, /register, /verify-email, /forgot-password y
      // /reset-password se registran en la propuesta 002-app-auth — el
      // guard ya las trata como públicas.
    ],
  );
}
```

## 17. `lib/core/theme/app_colors.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';

/// Paleta Depredadog — fast-food, identidad "condimentos":
/// ketchup / mostaza / pan / parrilla / pepinillo.
/// Único archivo autorizado (junto a app_theme) para mencionar colores
/// literales. Cada rol tiene variante light y dark (ThemeMode.system).
class AppColors {
  AppColors._();

  // ---- Light ----
  static const Color primaryLight = Color(0xFFD62828); // rojo ketchup
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color secondaryLight = Color(0xFFFBBF24); // amarillo mostaza
  static const Color onSecondaryLight = Color(0xFF4A2511);
  static const Color tertiaryLight = Color(0xFF5B8C3A); // verde pepinillo
  static const Color onTertiaryLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFF3D6); // crema pan
  static const Color onSurfaceLight = Color(0xFF4A2511); // marrón parrilla
  static const Color errorLight = Color(0xFFB3261E);
  static const Color onErrorLight = Color(0xFFFFFFFF);

  // ---- Dark (derivadas de la misma familia) ----
  static const Color primaryDark = Color(0xFFFF8A7A); // ketchup suavizado
  static const Color onPrimaryDark = Color(0xFF4A0000);
  static const Color secondaryDark = Color(0xFFFCD34D); // mostaza suavizada
  static const Color onSecondaryDark = Color(0xFF3D2B00);
  static const Color tertiaryDark = Color(0xFF8FBF6A);
  static const Color onTertiaryDark = Color(0xFF1E3A0F);
  static const Color surfaceDark = Color(0xFF241511); // parrilla profundo
  static const Color onSurfaceDark = Color(0xFFFFF3D6); // crema pan
  static const Color errorDark = Color(0xFFF2B8B5);
  static const Color onErrorDark = Color(0xFF601410);

  /// Marca sobre fondos del backdrop (degradado ketchup → mostaza) —
  /// siempre blanco.
  static const Color onBrandGradient = Color(0xFFFFFFFF);
}
```

## 18. `lib/core/theme/app_theme.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tema Material 3 de Depredadog (light + dark). Los widgets consumen
/// Theme.of(context) — nunca AppColors directo salvo marca sobre gradiente.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryLight,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryLight,
          onPrimary: AppColors.onPrimaryLight,
          secondary: AppColors.secondaryLight,
          onSecondary: AppColors.onSecondaryLight,
          tertiary: AppColors.tertiaryLight,
          onTertiary: AppColors.onTertiaryLight,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
          error: AppColors.errorLight,
          onError: AppColors.onErrorLight,
        ),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryDark,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primaryDark,
          onPrimary: AppColors.onPrimaryDark,
          secondary: AppColors.secondaryDark,
          onSecondary: AppColors.onSecondaryDark,
          tertiary: AppColors.tertiaryDark,
          onTertiary: AppColors.onTertiaryDark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
          error: AppColors.errorDark,
          onError: AppColors.onErrorDark,
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

## 19. `lib/core/widgets/app_backdrop.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Backdrop de marca: degradado ketchup → mostaza ocupando el
/// tercio superior de la pantalla. Las screens lo ponen tras su contenido:
/// Scaffold → AppBackdrop → listeners → scroll (bloc-patterns).
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ColoredBox(color: scheme.surface),
          ),
        ],
      ),
    );
  }
}

/// Icono de marca reutilizable — la "flama" de Depredadog.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.local_fire_department_rounded,
      size: size,
      color: AppColors.onBrandGradient,
    );
  }
}
```

## 20. `lib/core/screens/splash_screen.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../routes/auth_guard.dart';
import '../theme/app_colors.dart';
import '../widgets/app_backdrop.dart';

/// Splash de marca: flama + nombre + tagline. Tras ~1.2s navega según el
/// estado de sesión (el guard decide — sin sesión cae en /welcome).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.go(AuthGuard.welcomeRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          const AppBackdrop(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrandMark(),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.onBrandGradient,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.splashTagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onBrandGradient.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 21. `lib/core/screens/welcome_screen.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_backdrop.dart';

/// PROVISIONAL: placeholder de bienvenida hasta que 002-app-auth traiga el
/// flujo real (login/registro). Sirve para validar el bootstrap en device.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const AppBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppBrandMark(),
                    const SizedBox(height: 24),
                    Text(
                      l10n.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.onBrandGradient,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.welcomeBody,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.welcomeAuthPending,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 22. `lib/core/di/setup_di.dart` (archivo nuevo)

```dart
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
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

## 23. `lib/app.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/setup_di.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

/// Raíz de la app: MaterialApp.router con tema M3 (system light/dark),
/// router propio y localización es.
class DepredadogApp extends StatelessWidget {
  const DepredadogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Depredadog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: locator<AppRouter>().router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
    );
  }
}
```

## 24. `lib/main.dart` (archivo existente — reescritura total)

```dart
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';

void main() {
  AppBootstrap.run(const DepredadogApp());
}
```

## 25. `lib/core/bootstrap/app_bootstrap.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import '../di/setup_di.dart';

/// Orquesta el arranque: bindings → DI → runApp. Punto único para agregar
/// inicializaciones futuras (Crashlytics, orientación, splash nativo).
class AppBootstrap {
  AppBootstrap._();

  static void run(Widget app) {
    WidgetsFlutterBinding.ensureInitialized();
    setupDI();
    runApp(app);
  }
}
```

## 26. `android/app/build.gradle.kts` (archivo existente — actualización)

`flutter_secure_storage` requiere minSdk ≥ 23.

**Antes:**

```kotlin
        minSdk = flutter.minSdkVersion
```

**Después:**

```kotlin
        minSdk = 23
```

## 27. `test/widget_test.dart` (archivo existente — reemplazo)

El test del counter desaparece; el smoke del core vive en los tests nuevos
de abajo. El archivo queda como suite índice mínima:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Los tests del core viven replicando lib/ en test/core/... (ver
  // testing-workflow). Este archivo queda como punto de entrada de suite.
  test('placeholder', () => expect(true, isTrue));
}
```

(Alternativa aceptable: borrar el archivo. Se conserva vacío-funcional para
no romper ningún script que espere `test/widget_test.dart`.)
```

## 28. `test/core/routes/auth_guard_test.dart` (archivo nuevo)

Pieza de seguridad — prioridad de cobertura según `testing-workflow`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';

void main() {
  group('AuthGuard', () {
    test('sin sesión: ruta pública pasa, protegida redirige a /welcome', () {
      final guard = AuthGuard(isAuthenticated: () => false);

      expect(guard.redirect(AuthGuard.welcomeRoute), isNull);
      expect(guard.redirect(AuthGuard.loginRoute), isNull);
      expect(guard.redirect('/welcome/cualquier-hija'), isNull);
      expect(guard.redirect(AuthGuard.homeRoute), AuthGuard.welcomeRoute);
      expect(guard.redirect('/perfil'), AuthGuard.welcomeRoute);
    });

    test('con sesión: ruta de auth redirige a /home, protegida pasa', () {
      final guard = AuthGuard(isAuthenticated: () => true);

      expect(guard.redirect(AuthGuard.loginRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.registerRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.homeRoute), isNull);
    });

    test('con sesión: splash no redirige (decide la propia pantalla)', () {
      final guard = AuthGuard(isAuthenticated: () => true);
      expect(guard.redirect(AuthGuard.splashRoute), isNull);
    });

    test('publicRoutes inyectable por constructor (DIP)', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        publicRoutes: {'/beta'},
      );
      expect(guard.redirect('/beta'), isNull);
      expect(guard.redirect(AuthGuard.welcomeRoute), AuthGuard.welcomeRoute);
    });
  });
}
```

## 29. `test/core/constants/environment_test.dart` (archivo nuevo)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/constants/environment/environment.dart';

void main() {
  group('Environment', () {
    test('sin --dart-define cae en dev con URL de emulador Android', () {
      // En flutter test no hay dart-defines → defaults
      expect(Environment.currentEnvironment, EnvType.dev);
      expect(Environment.apiBaseUrl, 'http://10.0.2.2:3000');
      expect(Environment.isDev, isTrue);
      expect(Environment.isProd, isFalse);
    });
  });
}
```

## 30. `test/core/screens/welcome_screen_test.dart` (archivo nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/screens/welcome_screen.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  testWidgets('WelcomeScreen muestra marca y textos localizados',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const WelcomeScreen(),
      ),
    );

    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.text('Bienvenido a Depredadog'), findsOneWidget);
    expect(find.text('Acceso disponible muy pronto'), findsOneWidget);
  });
}
```

## 31. `Design/design-system.yaml` (archivo existente — actualización)

Bump **minor** a `1.1.0` (primera paleta real + primeras specs visuales —
`design-system-docs`).

**Antes:**

```yaml
meta:
  product: Depredadog
  version: 1.0.1
  updated: 2026-10-23

palette:
  # Seed mínima — redefinir al clonar el template para un producto real.
  primary: "#1565C0"
  on_primary: "#FFFFFF"
  surface: "#FFFFFF"
  on_surface: "#212121"
  error: "#B00020"
```

**Después:**

```yaml
meta:
  product: Depredadog
  version: 1.1.0
  updated: <fecha de implementación>

palette:
  # Identidad Depredadog — "condimentos" (definida por el usuario, §001):
  # ketchup / mostaza / pan / parrilla / pepinillo.
  primary_light: "#D62828"
  secondary_light: "#FBBF24"
  tertiary_light: "#5B8C3A"
  surface_light: "#FFF3D6"
  on_surface_light: "#4A2511"
  error_light: "#B3261E"
  primary_dark: "#FF8A7A"
  secondary_dark: "#FCD34D"
  tertiary_dark: "#8FBF6A"
  surface_dark: "#241511"
  on_surface_dark: "#FFF3D6"
  error_dark: "#F2B8B5"
  on_brand_gradient: "#FFFFFF"
```

Y al final del `components:`/`screens:` + `changelog`:

```yaml
components:
  app_backdrop:
    description: "Degradado llama primary→secondary ocupando el tercio superior; el resto surface. Va tras el contenido en Stack."
  app_brand_mark:
    description: "Icono de marca (flama redondeada), 80px default, siempre on_brand_gradient sobre el backdrop."

screens:
  splash:
    route: "/"
    spec: "AppBackdrop + AppBrandMark + appName (headline w800) + tagline sobre gradiente; navega a /welcome tras 1.2s."
  welcome:
    route: "/welcome"
    status: "provisional — reemplazará el flujo auth de 002"
    spec: "Backdrop + brand mark + título + card con copy temporal."

changelog:
  - version: "1.1.0"
    date: <fecha>
    status: "completed"
    changes:
      - "Paleta real Depredadog 'condimentos' (ketchup/mostaza/pan/parrilla/pepinillo, definida por el usuario) reemplaza el seed genérico (§001-app-bootstrap)."
      - "Primeras specs visuales: app_backdrop, app_brand_mark, splash, welcome (provisional)."
      - "Tema M3 light+dark, botones 48px radius 12, inputs radius 12."
```

(Las entradas anteriores `1.0.0`/`1.0.1` del changelog se conservan intactas
debajo de esta nueva.)

## 32. `../pcalientes_backend/pendientes/003-crashlytics-app.md` (archivo nuevo)

Seguir el formato de `pendientes/001` y `002` (carpeta compartida).

```markdown
# Pendiente: Crashlytics / logger de producción en la app

**Estado:** pendiente
**Origen:** propuesta 001-app-bootstrap (app)
**Bloquea deploy a producción:** sí (observabilidad)

## Contexto

`setup_di.dart` registra `DebugLoggerServiceImpl` para `ILoggerService` en
todos los entornos — marcado `// PROVISIONAL`. En release `debugPrint` es
no-op, así que un crash en prod no deja rastro.

## Qué falta

- Integrar Firebase Crashlytics (`firebase_core` + `firebase_crashlytics`) y
  crear `CrashlyticsLoggerServiceImpl`; resolver impl por
  `bool.fromEnvironment('dart.vm.product')` como prevé `promt_solid`.
- Decisión previa: proyecto Firebase de Depredadog + `google-services.json`/
  `GoogleService-Info.plist` (secretos — no commitear).

## Alternativa evaluable

Sentry (`sentry_flutter`) si no se quiere Firebase — misma idea: el impl se
swapea en `setup_di` sin tocar consumers (el puerto ya está).
```

---

## Orden de aplicación

1. `pubspec.yaml` (deps + `generate: true`) → `flutter pub get`
2. `l10n.yaml` + `app_es.arb` → `flutter gen-l10n`
3. `environment.dart` + logging (puerto + impl)
4. Network: `INetworkInfo` + impl + excepciones + `INetworkService` + Dio impl
5. Storage: `ISecureStorage` + impl
6. `auth_guard.dart` → `custom_transitions.dart` → `app_router.dart`
7. `app_colors.dart` → `app_theme.dart` → `app_backdrop.dart`
8. Screens: `splash_screen.dart` + `welcome_screen.dart`
9. `setup_di.dart` → `app_bootstrap.dart` → `app.dart` → `main.dart`
10. `build.gradle.kts` (minSdk 23)
11. Tests (3 archivos) + reemplazo de `widget_test.dart`
12. `design-system.yaml` (bump + specs + changelog)
13. `pendientes/003-crashlytics-app.md` (en el repo backend — carpeta compartida)
14. Verificación: `flutter analyze` → `flutter test` → `flutter run` en
    emulador para validación visual del usuario

## Checklist final

- [x] `environments-secrets`: cero URLs/tokens quemados; `Environment` es el
      único emisor de `--dart-define`; interceptor de logging solo en dev.
- [x] `solid-clean-architecture`: puertos + impls, DI por capas, sin
      `dynamic` en APIs públicas (retorno `dynamic` de red es la convención —
      el mapeo a models ocurre en datasources de features), sin `print`.
- [x] `navigation-routing`: rutas completas solo en `AuthGuard`, page
      builders vía `CustomTransitions`, guard desacoplado de GoRouterState.
- [x] `i18n-workflow`: todo texto visible en `app_es.arb` + `gen-l10n`.
- [x] `ui-design-standard`: cero `Colors.*` fuera de theme, escala de
      espaciado respetada.
- [x] `testing-workflow`: AuthGuard + Environment + Welcome screen testeados.
- [x] `design-system-docs`: bump 1.1.0 con specs + changelog.
- [x] `pendientes-produccion`: Crashlytics documentado en la carpeta
      compartida del backend.

