# Propuesta 007: Integración `GET /auth/me` — restaurar sesión al abrir la app

Cierra el pendiente 007: hoy cerrar y reabrir la app pierde la sesión aunque
los tokens sigan guardados. El splash ya tiene el hook documentado
("esta pantalla decide login vs home") — esta propuesta lo implementa.

**Hechos del contrato backend (verificados contra el código NestJS):**

- `GET /auth/me` — autenticado por JWT (no `@Public`, sin throttle propio).
- 200 → `UserResponseDto`: mismo shape que el `user` de login/verify —
  `UserModel.fromJson` lo parsea sin cambios.
- 401 para TODO: token faltante/vencido/inválido, sesión revocada o
  expirada, usuario no-ACTIVE (`SessionNotFoundException` → 401
  "Session is no longer valid"). No distingue motivos — la app trata 401
  como "sesión inválida" y ya.
- El `AuthInterceptor` ya adjunta `Bearer` automáticamente — el datasource
  no arma headers.

**Decisiones embebidas (a confirmar en la encuesta):**

| Decisión | Propuesta |
|---|---|
| Restaurar sin conexión | **→ /login conservando los tokens** — la sesión sigue válida, solo no pudo validarse; el próximo arranque restaura. Rechazada la alternativa optimista (entrar a /home sin validar) |
| Objeto user de `/me` | **Guardarlo en `AuthSession.currentUser`** — ya viene en la respuesta; evita una segunda llamada cuando /home lo necesite (saludo, perfil). `markAuthenticated(user)` lo fija junto al flag |
| Timeout del restore | **Sin timer propio** — el timeout de Dio ya limita; un tope adicional de ~4s haría fallar restauraciones legítimas en red lenta |

**Semántica por outcome (splash nunca muestra toast — restaurar es
best-effort y silencioso):**

| Outcome | Acción |
|---|---|
| 200 + user | `AuthSession.markAuthenticated(user)` → `/home` |
| Sin token guardado | → `/login` (ni siquiera llama a la red) |
| 401 (token/sesión muertos o cuenta no-ACTIVE) | `clearSession()` en el repo → `/login` |
| Sin conexión / 5xx / timeout | → `/login`, tokens INTACTOS |

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/failures/auth_failure.dart` | +`SessionExpiredFailure`, +`NoStoredSessionFailure` |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | +`restoreSession()` |
| `lib/features/auth/domain/use_cases/restore_session_use_case.dart` | **Nuevo** |
| `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart` | +`getMe()` |
| `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart` | +`getMe()` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | +`restoreSession()` con la semántica de la tabla |
| `lib/core/auth/auth_session.dart` | `markAuthenticated(user)` + `currentUser` |
| `lib/features/auth/presentation/cubit/splash_cubit.dart` + `splash_state.dart` | **Nuevo** — orquesta el restore |
| `lib/core/screens/splash_screen.dart` | Tras el delay de marca: `SplashCubit.restoreSession()` → home o login |
| `lib/core/di/setup_di.dart` | Registrar use case + cubit |
| `lib/features/auth/presentation/cubit/login_cubit.dart` | `markAuthenticated(user)` — nueva firma |
| `lib/features/auth/presentation/cubit/verify_email_cubit.dart` | `markAuthenticated(user)` — nueva firma |
| `pendientes/` | Cerrar el ítem 007 (restaurar sesión) |
| `test/…` | Repository me-paths, use case, splash cubit, auth_session; ajustar tests de login/verify cubit a la nueva firma |

---

## 1. `auth_failure.dart` (actualización)

```dart
/// 401 en /auth/me — token vencido/inválido, sesión revocada o cuenta que
/// ya no está ACTIVE (el backend no distingue — SessionNotFoundException).
/// El repositorio ya borró los tokens locales cuando emite esto.
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure();
}

/// No hay tokens en secure storage — ni siquiera se intenta la red.
/// Resultado normal del primer arranque, no un error visible al usuario.
class NoStoredSessionFailure extends AuthFailure {
  const NoStoredSessionFailure();
}
```

## 2. `i_auth_repository.dart` (actualización)

```dart
  /// Valida la sesión guardada contra el backend. Solo el splash la usa
  /// (decidir login vs home al abrir). Semántica por resultado:
  /// Right(user) = sesión válida; SessionExpiredFailure = 401, tokens ya
  /// borrados; NoStoredSessionFailure = sin token local; NoConnection/
  /// Unknown = no pudo validarse, tokens se conservan.
  Future<Either<AuthFailure, User>> restoreSession();
```

## 3. `restore_session_use_case.dart` (nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/restore_session_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por acción — valida la sesión persistida al
/// abrir la app (única llamada del splash). El repositorio resuelve la
/// semántica (sin token, 401 → limpiar, offline → conservar); el caller
/// solo bifurca éxito → /home o fracaso → /login.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call() => _repository.restoreSession();
}
```

## 4. `i_auth_remote_datasource.dart` (actualización)

```dart
  /// GET /auth/me — el AuthInterceptor adjunta el Bearer guardado; acá no
  /// se arman headers. Devuelve el usuario crudo (UserResponseDto).
  Future<UserModel> getMe();
```

## 5. `auth_remote_datasource_impl.dart` (actualización)

```dart
  @override
  Future<UserModel> getMe() async {
    final response = await _networkService.get('/auth/me');
    return UserModel.fromJson(response as Map<String, dynamic>);
  }
```

(verificar que `INetworkService.get` exista — si solo hay `post`, se agrega
el `get` al servicio de red siguiendo el mismo patrón; ajuste menor.)

## 6. `auth_repository_impl.dart` (actualización)

```dart
  @override
  Future<Either<AuthFailure, User>> restoreSession() async {
    // Fast path: sin token guardado ni siquiera tocamos red ni
    // conectividad — el splash resuelve a /login de inmediato.
    final token = await _localDataSource.readAccessToken();
    if (token == null || token.isEmpty) {
      return const Left(NoStoredSessionFailure());
    }
    if (!await _networkInfo.isConnected) {
      // Conservar tokens: la sesión puede seguir válida; el próximo
      // arranque restaura. No es un "logout".
      return const Left(NoConnectionFailure());
    }
    try {
      final user = await _remoteDataSource.getMe();
      return Right(user);
    } on NetworkException catch (e) {
      if (e.statusCode == 401) {
        // El server declaró la sesión inválida — los tokens locales son
        // basura (también cubre sesión revocada y cuenta suspendida).
        await _localDataSource.clearSession();
        return const Left(SessionExpiredFailure());
      }
      // 429/5xx/timeout: transitorio — conservar tokens.
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(UnknownAuthFailure(e.toString()));
    }
  }
```

## 7. `auth_session.dart` (actualización)

```dart
/// SOLID (SRP): única verdad en memoria de "¿hay sesión activa en este
/// proceso?" + quién es el usuario. AuthGuard lee el flag de forma
/// síncrona (el guard no puede ser async); la fuente persistida son los
/// tokens en secure storage — esto es solo el reflejo en RAM.
class AuthSession {
  bool _isAuthenticated = false;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;

  /// Null hasta el primer login/verify/restore exitoso del proceso.
  User? get currentUser => _currentUser;

  void markAuthenticated(User user) {
    _isAuthenticated = true;
    _currentUser = user;
  }

  void markLoggedOut() {
    _isAuthenticated = false;
    _currentUser = null;
  }
}
```

## 8. `splash_state.dart` + `splash_cubit.dart` (nuevos)

**Ruta:** `lib/features/auth/presentation/cubit/splash_state.dart`

```dart
import 'package:equatable/equatable.dart';

/// El splash solo bifurca éxito/fracaso — no le interesa el motivo del
/// Left (la semántica de limpiar/conservar tokens vive en el repositorio).
enum SplashStatus { restoring, restored, guest }

class SplashState extends Equatable {
  const SplashState({this.status = SplashStatus.restoring});

  final SplashStatus status;

  @override
  List<Object?> get props => [status];
}
```

**Ruta:** `lib/features/auth/presentation/cubit/splash_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session.dart';
import '../../domain/use_cases/restore_session_use_case.dart';
import 'splash_state.dart';

/// Orquesta la restauración de sesión al abrir la app — la única lógica
/// de la splash screen (bloc-patterns: la pantalla queda dumb). Éxito →
/// marca AuthSession (igual que login/verify); fracaso → guest, la
/// pantalla navega a /login sin más detalle.
class SplashCubit extends Cubit<SplashState> {
  SplashCubit({
    required RestoreSessionUseCase restoreSessionUseCase,
    required AuthSession authSession,
  }) : _restoreSession = restoreSessionUseCase,
       _authSession = authSession,
       super(const SplashState());

  final RestoreSessionUseCase _restoreSession;
  final AuthSession _authSession;

  /// Devuelve el Future para que la pantalla lo espere EN PARALELO con su
  /// delay de marca — la navegación sale en max(800ms, restore).
  Future<void> restoreSession() async {
    final result = await _restoreSession();
    if (isClosed) return;
    result.fold(
      (_) => emit(const SplashState(status: SplashStatus.guest)),
      (user) {
        _authSession.markAuthenticated(user);
        emit(const SplashState(status: SplashStatus.restored));
      },
    );
  }
}
```

## 9. `splash_screen.dart` (actualización)

Reemplaza el cuerpo de `_goNext` — el restore corre EN PARALELO con el
delay de marca (no suma latencia; la marca mínima de 800ms se conserva):

```dart
  Future<void> _goNext() async {
    final cubit = context.read<SplashCubit>();
    // Fire-and-remember: el restore arranca YA en paralelo con la marca —
    // se espera al final para navegar en max(800ms, respuesta del server).
    final restore = cubit.restoreSession();
    await precacheImage(
      AssetImage(_imagotypeAsset),
      context,
    ).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await restore;
    if (!mounted) return;
    context.go(
      cubit.state.status == SplashStatus.restored
          ? AuthGuard.homeRoute
          : AuthGuard.loginRoute,
    );
  }
```

El `build` envuelve el Scaffold en `BlocProvider<SplashCubit>(create: (_) =>
locator<SplashCubit>(), …)` — mismo patrón de wiring que login/verify.

## 10. `login_cubit.dart` / `verify_email_cubit.dart` (ajuste de firma)

`markAuthenticated()` → `markAuthenticated(user)` en ambos Right-branches
(ya tienen el `user` del Either). Sin otro cambio.

## 11. `setup_di.dart` (actualización)

```dart
  // --- Use Cases (auth) ---
  locator.registerLazySingleton<RestoreSessionUseCase>(
    () => RestoreSessionUseCase(locator<IAuthRepository>()),
  );

  // --- Cubits ---
  locator.registerFactory<SplashCubit>(
    () => SplashCubit(
      restoreSessionUseCase: locator<RestoreSessionUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
```

## 12. `pendientes/` — cerrar el ítem 007

Marcar "restaurar sesión con /auth/me" como resuelto según el formato de la
carpeta (mismo estilo que los ítems cerrados anteriores).

## 13. Tests

- **Repository** (`auth_repository_impl_test.dart`): sin token →
  `NoStoredSessionFailure` sin tocar red; offline → `NoConnectionFailure`
  conservando tokens; 200 → Right(user); 401 → `SessionExpiredFailure` +
  `clearSession` llamado; 500 → `UnknownAuthFailure` conservando tokens.
- **Use case** (`restore_session_use_case_test.dart`, nuevo): delega y
  propaga ambos lados del Either.
- **Splash cubit** (`splash_cubit_test.dart`, nuevo): Right →
  `markAuthenticated` + status restored; Left → status guest, sin tocar
  AuthSession.
- **AuthSession**: markAuthenticated guarda user; markLoggedOut limpia.
- **Login/Verify cubit tests**: ajustar a `markAuthenticated(user)` —
  verificar `authSession.currentUser` además del flag.
- **Splash screen test**: si existe, ajustar al BlocProvider nuevo
  (stub del cubit vía locator como hacen los screen tests hermanos).

---

## Orden de aplicación

1. `auth_failure.dart` (+2 failures) → `i_auth_repository.dart` →
   `restore_session_use_case.dart`.
2. `i_auth_remote_datasource.dart` → impl (+`get` en network service si
   falta) → `auth_repository_impl.dart`.
3. `auth_session.dart` (firma nueva) → `splash_state/cubit` →
   `splash_screen.dart` → ajuste de call sites en login/verify cubit.
4. `setup_di.dart` → `pendientes/`.
5. Tests → `flutter analyze` + `flutter test`.
6. Verificación manual: login (ana@) → /home → matar y reabrir la app →
   splash → directo a /home sin login. Casos borde: borrar la sesión en el
   server (401) → splash → /login; modo avión → splash → /login, y al
   volver la red reabre a /home.
