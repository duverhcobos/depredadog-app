# Propuesta: local cerrado → mensaje en lugar del CTA (carrito + checkout)

Decisión del usuario tras ver §028 en vivo: con el local cerrado, el "Ir a pagar" del carrito y el "Confirmar pedido" del checkout **no deben verse como botón deshabilitado** — el mensaje ocupa el lugar del botón. La carrera (cerrar entre pantalla y confirm) sigue resolviéndose con la fila de error post-POST que §028 ya mostró — esa no cambia.

Hoy el carrito ni siquiera conoce el estado del local y el chip del header es `isOpen: true` hardcodeado (mock documentado "lo alimenta el módulo store"). Esta propuesta crea la feature `store` — fuente única de verdad para abierto/cerrado — que alimenta el chip, el carrito y futuras pantallas. El checkout conserva su propio fetch (`/store/config` le trae fee/dirección/mínimo además de `isOpen`).

**Bonus corregido:** el chip Abierto/Cerrado del header pasa de mock a real.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/store/domain/entities/store_open_state.dart` | **nuevo** — enum tri-estado |
| `lib/features/store/domain/failures/store_failure.dart` | **nuevo** |
| `lib/features/store/domain/repositories/i_store_repository.dart` | **nuevo** |
| `lib/features/store/data/datasources/interfaces/i_store_remote_datasource.dart` | **nuevo** |
| `lib/features/store/data/datasources/implementations/store_remote_datasource_impl.dart` | **nuevo** — GET /store/config → isOpen |
| `lib/features/store/data/repositories/store_repository_impl.dart` | **nuevo** |
| `lib/features/store/presentation/cubit/store_status_cubit.dart` | **nuevo** — Cubit<StoreOpenState> + refresh() |
| `lib/core/di/setup_di.dart` | registros store |
| `lib/core/routes/app_router.dart` | `StoreStatusCubit` al MultiBlocProvider del shell (`..refresh()`) |
| `lib/core/layout/shell_header.dart` | chip real (unknown → se oculta) |
| `lib/features/cart/presentation/screens/cart_screen.dart` | Stateful + refresh al entrar + footer: CTA ↔ mensaje |
| `lib/features/checkout/presentation/screens/checkout_screen.dart` | cerrado → mensaje en el slot del CTA (banner cerrado sale) |
| `lib/l10n/app_es.arb` | `cartStoreClosed` nuevo + texto de `checkoutStoreClosed` |
| `test/features/store/**` | **nuevos** — repo + cubit |
| `test/.../cart_screen_test.dart`, `checkout_screen_test.dart`, `app_shell_layout_test.dart` | provider nuevo + casos cerrado |

Modelo de estado: `StoreOpenState { open, closed, unknown }` — `unknown` cubre "aún no se consultó" y "la consulta falló" (offline/5xx). Semántica: **solo `closed` confirmado bloquea el CTA**; `unknown` deja el botón habilitado — el checkout tiene su propia compuerta con retry y el backend rechaza igual (cerrado por defecto no aplica acá porque hay compuerta downstream real, no es la última línea).

---

## 1. `store_open_state.dart` (archivo nuevo)

**Ruta:** `lib/features/store/domain/entities/store_open_state.dart`

```dart
/// Estado operativo del local — lo resuelve GET /store/config
/// (backend 013). `unknown` cubre "aún no se consultó" y "la
/// consulta falló": solo `closed` CONFIRMADO bloquea CTAs; unknown
/// deja pasar porque el checkout tiene su propia compuerta con
/// retry y el backend es la última línea (§029 — decisión usuario).
enum StoreOpenState { open, closed, unknown }
```

## 2. `store_failure.dart` (archivo nuevo)

**Ruta:** `lib/features/store/domain/failures/store_failure.dart`

```dart
import 'package:equatable/equatable.dart';

/// Fallo consultando el estado del local — un solo caso: cualquier
/// causa (offline, 4xx/5xx, inesperado) degrada a `unknown`, nunca a
/// "cerrado" fingido. `message` solo para logging.
sealed class StoreFailure extends Equatable {
  const StoreFailure();

  @override
  List<Object?> get props => [];
}

final class StoreFetchFailure extends StoreFailure {
  const StoreFetchFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

## 3. `i_store_repository.dart` (archivo nuevo)

**Ruta:** `lib/features/store/domain/repositories/i_store_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/store_open_state.dart';
import '../failures/store_failure.dart';

/// Estado operativo del local (§029) — lo consumen el chip del
/// header, el carrito y futuras pantallas; el checkout mantiene su
/// fetch propio porque necesita el config completo (fee/dirección).
abstract interface class IStoreRepository {
  /// GET /store/config → abierto/cerrado ahora. Either solo para
  /// propagar el fallo de red; el cubit lo convierte en `unknown`.
  Future<Either<StoreFailure, StoreOpenState>> getOpenState();
}
```

## 4. `i_store_remote_datasource.dart` (archivo nuevo)

**Ruta:** `lib/features/store/data/datasources/interfaces/i_store_remote_datasource.dart`

```dart
import '../../../domain/entities/store_open_state.dart';

/// Fuente remota del estado del local — GET /store/config.
abstract interface class IStoreRemoteDataSource {
  /// Lanza NetworkException; el repositorio la traduce.
  Future<StoreOpenState> fetchOpenState();
}
```

## 5. `store_remote_datasource_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/store/data/datasources/implementations/store_remote_datasource_impl.dart`

```dart
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../../domain/entities/store_open_state.dart';
import '../interfaces/i_store_remote_datasource.dart';

/// GET /store/config → `isOpen` del negocio (backend 013). Solo lee
/// ese campo — el config completo (fee/dirección/horario) lo consume
/// el checkout por su propio datasource.
class StoreRemoteDataSourceImpl implements IStoreRemoteDataSource {
  const StoreRemoteDataSourceImpl({required this.networkService});

  final INetworkService networkService;

  @override
  Future<StoreOpenState> fetchOpenState() async {
    final response = await networkService.get('/store/config');
    final data = response.data;
    // Parseo defensivo: body no-Map o isOpen ausente → `unknown`
    // (no se finge cerrado ni abierto — el consumidor decide).
    if (data is! Map<String, dynamic>) return StoreOpenState.unknown;
    final isOpen = data['isOpen'];
    return isOpen is bool
        ? (isOpen ? StoreOpenState.open : StoreOpenState.closed)
        : StoreOpenState.unknown;
  }
}
```

## 6. `store_repository_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/store/data/repositories/store_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/store_open_state.dart';
import '../../domain/failures/store_failure.dart';
import '../../domain/repositories/i_store_repository.dart';
import '../datasources/interfaces/i_store_remote_datasource.dart';

/// SOLID (SRP): datasource + conectividad; traduce NetworkException
/// → StoreFailure — mismo `_guard` mínimo de OrdersRepositoryImpl.
/// La UI nunca ve excepciones crudas (§029).
class StoreRepositoryImpl implements IStoreRepository {
  const StoreRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  final IStoreRemoteDataSource remoteDataSource;
  final INetworkInfo networkInfo;

  @override
  Future<Either<StoreFailure, StoreOpenState>> getOpenState() async {
    if (!await networkInfo.isConnected) {
      return const Left(StoreFetchFailure('Sin conexión'));
    }
    try {
      return Right(await remoteDataSource.fetchOpenState());
    } on NetworkException catch (e) {
      return Left(StoreFetchFailure(e.message));
    } catch (e) {
      return Left(StoreFetchFailure(e.toString()));
    }
  }
}
```

## 7. `store_status_cubit.dart` (archivo nuevo)

**Ruta:** `lib/features/store/presentation/cubit/store_status_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/store_open_state.dart';
import '../../domain/repositories/i_store_repository.dart';

/// Estado del local como enum directo (§029) — no necesita clase de
/// estado: el único dato es abierto/cerrado/desconocido.
///
/// Singleton de shell (registrado en DI + BlocProvider.value del
/// router, como CatalogCubit): el chip del header lo muestra siempre;
/// el carrito dispara refresh() al entrar para que el estado esté
/// fresco donde importa (la puerta del pago).
///
/// `refresh()` fallido → `unknown` solo si aún no se conoce nada:
/// un refresh que falla DESPUÉS de un estado conocido conserva el
/// último valor (un parpadeo de red no debe apagar el chip ni
/// bloquear el carrito — la compuerta real es el checkout/backend).
class StoreStatusCubit extends Cubit<StoreOpenState> {
  StoreStatusCubit({required IStoreRepository repository})
      : _repository = repository,
        super(StoreOpenState.unknown);

  final IStoreRepository _repository;

  Future<void> refresh() async {
    final result = await _repository.getOpenState();
    result.fold(
      (_) {
        if (state == StoreOpenState.unknown) {
          emit(StoreOpenState.unknown); // no-op: ya desconocido
        }
        // Estado conocido → se conserva (último valor válido).
      },
      emit,
    );
  }
}
```

## 8. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

Después del bloque `// --- Carrito (propuesta 020)`:

**Antes:**
```dart
  locator.registerLazySingleton<CartCubit>(() => CartCubit());

  // --- Checkout (propuestas 025+026): datasource + repo + use-cases
```

**Después:**
```dart
  locator.registerLazySingleton<CartCubit>(() => CartCubit());

  // --- Store (propuesta 029): estado abierto/cerrado del local —
  // singleton de shell: alimenta el chip del header y la compuerta
  // del carrito. El checkout trae su propio fetch (config completo).
  locator.registerLazySingleton<IStoreRemoteDataSource>(
    () => StoreRemoteDataSourceImpl(
      networkService: locator<INetworkService>(),
    ),
  );
  locator.registerLazySingleton<IStoreRepository>(
    () => StoreRepositoryImpl(
      remoteDataSource: locator<IStoreRemoteDataSource>(),
      networkInfo: locator<INetworkInfo>(),
    ),
  );
  locator.registerLazySingleton<StoreStatusCubit>(
    () => StoreStatusCubit(repository: locator<IStoreRepository>()),
  );

  // --- Checkout (propuestas 025+026): datasource + repo + use-cases
```

(Y los imports correspondientes de la feature `store`.)

## 9. `app_router.dart` (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
        builder: (context, state, navigationShell) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locator<CatalogCubit>()..load()),
            BlocProvider.value(value: locator<CartCubit>()),
          ],
```

**Después:**
```dart
        builder: (context, state, navigationShell) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locator<CatalogCubit>()..load()),
            BlocProvider.value(value: locator<CartCubit>()),
            // §029 — estado del local al nivel del shell: el chip del
            // header es real desde el arranque (mata el mock isOpen:
            // true) y el carrito/checkout lo leen con watch.
            BlocProvider.value(
              value: locator<StoreStatusCubit>()..refresh(),
            ),
          ],
```

## 10. `shell_header.dart` (archivo existente — actualización)

**Ruta:** `lib/core/layout/shell_header.dart`

**Antes:**
```dart
            const Spacer(),
            // Estado del local — junto a las notificaciones (§017,
            // isOpen mock provisional; lo alimenta el módulo store).
            const StoreStatusChip(isOpen: true),
```

**Después:**
```dart
            const Spacer(),
            // Estado del local REAL (§029 — StoreStatusCubit del
            // shell; mata el mock §017). `unknown` → chip oculto:
            // mejor no mostrar que mentir Abierto/Cerrado.
            BlocBuilder<StoreStatusCubit, StoreOpenState>(
              builder: (context, status) => status == StoreOpenState.unknown
                  ? const SizedBox.shrink()
                  : StoreStatusChip(isOpen: status == StoreOpenState.open),
            ),
```

(+ import de `store_status_cubit.dart` y `store_open_state.dart`.)

## 11. `cart_screen.dart` (archivo existente — actualización)

**Ruta:** `lib/features/cart/presentation/screens/cart_screen.dart`

`CartScreen` pasa a `StatefulWidget` (initState dispara el refresh del estado del local al entrar — mismo patrón "cada visita recarga" de §027):

**Antes:**
```dart
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
```

**Después:**
```dart
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // §029 — estado del local fresco al entrar al carrito: la
    // compuerta del "Ir a pagar" no puede mostrar un dato viejo.
    // Guard igual que el reload de OrdersCubit del shell (tests
    // aislados sin DI no deben reventar).
    if (locator.isRegistered<StoreStatusCubit>()) {
      locator<StoreStatusCubit>().refresh();
    }
  }

  void _removeItem(BuildContext context, CartItem item) {
    context.read<CartCubit>().removeItem(item.id);
    AppToast.info(
      context,
      AppLocalizations.of(context)!.cartItemRemoved(item.productName),
    );
  }

  @override
  Widget build(BuildContext context) {
```

(mover `_removeItem` y `build` dentro del State; cierre de clase queda igual)

El footer — el CTA cede su lugar al mensaje solo cuando el cerrado es CONFIRMADO:

**Antes:**
```dart
                              const SizedBox(width: 16),
                              Expanded(
                                child: FilledButton(
                                  // §022: push (no go) — volver del
                                  // checkout regresa al carrito con
                                  // sus ítems intactos.
                                  onPressed: () =>
                                      context.push(AuthGuard.checkoutRoute),
                                  child: Text(l10n.cartCheckoutCta),
                                ),
                              ),
```

**Después:**
```dart
                              const SizedBox(width: 16),
                              // §029 — solo `closed` CONFIRMADO
                              // reemplaza el CTA por el mensaje:
                              // unknown (sin consultar/falló) deja
                              // pasar — el checkout tiene compuerta
                              // propia con retry y el backend es la
                              // última línea.
                              Expanded(
                                child: BlocBuilder<
                                    StoreStatusCubit,
                                    StoreOpenState>(
                                  builder: (context, status) =>
                                      status == StoreOpenState.closed
                                      ? _StoreClosedMessage(
                                          message: l10n.cartStoreClosed,
                                        )
                                      : FilledButton(
                                          // §022: push (no go) —
                                          // volver del checkout
                                          // regresa al carrito con
                                          // sus ítems intactos.
                                          onPressed: () => context
                                              .push(AuthGuard.checkoutRoute),
                                          child: Text(l10n.cartCheckoutCta),
                                        ),
                                ),
                              ),
```

Y el widget compartido del mensaje (privado de este archivo lo reutiliza también el checkout? NO — se extrae a `core/widgets/` para que ambas pantallas usen el mismo):

**Widget nuevo compartido** — `lib/core/widgets/store_closed_message.dart`:

```dart
import 'package:flutter/material.dart';

/// Mensaje que OCUPA EL LUGAR DEL CTA cuando el local está cerrado
/// (§029 — decisión usuario: no botón deshabilitado). Misma familia
/// de los avisos inline: ícono info + texto en error, ocupando el
/// ancho del botón que reemplaza.
class StoreClosedMessage extends StatelessWidget {
  const StoreClosedMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 12. `checkout_screen.dart` (archivo existente — actualización)

**Ruta:** `lib/features/checkout/presentation/screens/checkout_screen.dart`

El banner `!isOpen → StoreStatusBanner` desaparece — el mensaje pasa al slot del CTA:

**Antes:**
```dart
                                if (state.storeFailed)
                                  StoreStatusBanner(
                                    message: l10n.checkoutStoreError,
                                    actionLabel: l10n.checkoutRetry,
                                    onAction: context
                                        .read<CheckoutCubit>()
                                        .loadCheckoutData,
                                  )
                                else if (!state.dataLoading &&
                                    !state.store.isOpen)
                                  StoreStatusBanner(
                                    message: l10n.checkoutStoreClosed,
                                  ),
```

**Después:**
```dart
                                if (state.storeFailed)
                                  StoreStatusBanner(
                                    message: l10n.checkoutStoreError,
                                    actionLabel: l10n.checkoutRetry,
                                    onAction: context
                                        .read<CheckoutCubit>()
                                        .loadCheckoutData,
                                  ),
                                // §029 — el cerrado ya no es banner
                                // sobre CTA deshabilitado: el mensaje
                                // ocupa el LUGAR del botón (abajo).
```

Y el botón:

**Antes (CTA del footer — aprox., el FilledButton del confirm):**
```dart
                                FilledButton(
                                  onPressed: canConfirm
                                      ? context.read<CheckoutCubit>().confirm
                                      : null,
                                  child: ...,
                                ),
```

**Después:**
```dart
                                // §029 — cerrado confirmado → el
                                // mensaje ocupa el slot del CTA (no
                                // botón deshabilitado). storeFailed
                                // conserva banner+retry arriba y el
                                // CTA deshabilitado (cerrado por
                                // defecto = seguro).
                                if (!state.dataLoading && !state.store.isOpen)
                                  StoreClosedMessage(
                                    message: l10n.checkoutStoreClosed,
                                  )
                                else
                                  FilledButton(
                                    onPressed: canConfirm
                                        ? context.read<CheckoutCubit>().confirm
                                        : null,
                                    child: ...,
                                  ),
```

(La fila `confirmError` — rechazo post-POST de §028 — queda intacta arriba de este bloque.)

## 13. `app_es.arb` (archivo existente — actualización)

**Ruta:** `lib/l10n/app_es.arb`

**Antes:**
```json
  "checkoutStoreClosed": "El local está cerrado ahora",
```

**Después:**
```json
  "checkoutStoreClosed": "El local está cerrado ahora — intenta en el horario de atención",
  "cartStoreClosed": "El local está cerrado ahora — intenta en el horario de atención",
  "@cartStoreClosed": {
    "description": "Mensaje que reemplaza al CTA 'Ir a pagar' del carrito con el local cerrado (§029)"
  },
```

(actualizar también la `@checkoutStoreClosed` describiendo el nuevo uso en el slot del CTA) — luego `flutter gen-l10n`.

## 14. Tests

- **`test/features/store/data/repositories/store_repository_impl_test.dart`** (nuevo): `isOpen:true→open`, `false→closed`, body sin isOpen→unknown (vía datasource mockeado), NoConnectionException→Left, sin conectividad→Left.
- **`test/features/store/presentation/cubit/store_status_cubit_test.dart`** (nuevo): refresh open/closed; fallo con estado unknown→sigue unknown; fallo con estado conocido→conserva el último valor.
- **`cart_screen_test.dart`**: harness provee `StoreStatusCubit` mockeado (como los demás cubits); caso closed→mensaje visible + CTA ausente; open/unknown→CTA presente.
- **`checkout_screen_test.dart`**: closed→`StoreClosedMessage` en el slot + sin FilledButton; storeFailed→banner+retry intacto; confirmError row intacto.
- **`app_shell_layout_test.dart`**: chip refleja el cubit real (Abierto/Cerrado/oculto en unknown).

---

## Orden de aplicación

1. Feature `store` completa (entity → failure → repo iface → datasource iface+impl → repo impl → cubit)
2. `setup_di.dart` + `app_router.dart` (provider en el shell)
3. `shell_header.dart` (chip real)
4. `core/widgets/store_closed_message.dart` + `cart_screen.dart` (stateful + footer)
5. `checkout_screen.dart` (CTA swap) + `app_es.arb` + `gen-l10n`
6. Tests nuevos + actualizados
7. `flutter analyze` + `flutter test` → revisor-estetico/revisor-ui (capturas) → usuario ve → revisor código → commit

## Anexo — encuesta de revisión (registrado)

| # | Pregunta | Respuesta del usuario |
|---|----------|------------------------|
| 1 | ¿`unknown` (consulta falló/sin responder) bloquea el "Ir a pagar"? | **Dejar pasar** — solo `closed` confirmado reemplaza el CTA; el checkout tiene su compuerta con retry y el backend es la última línea. |
| 2 | ¿Chip del header en `unknown`? | **Ocultarlo** — mejor no mostrar que mentir; un refresh fallido con estado conocido conserva el último valor. |
| 3 | ¿Copy en el lugar del CTA? | **Con sugerencia de horario** — "El local está cerrado ahora — intenta en el horario de atención", consistente con el rechazo §028. |

**Estado:** propuesta revisada y aprobada — lista para implementar.
