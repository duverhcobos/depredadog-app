# Propuesta: Cocina — avanzar y cancelar pedidos contra el backend real (PATCH /admin/orders/:id/status)

Segundo ciclo de integración de Cocina (§038 trajo la cola, §039 el
detalle). Los botones Confirmar / A la plancha / Listo / Entregado y la
cancelación con motivo dejan de ser mutaciones locales y pegan a
`PATCH /admin/orders/:id/status` (backend §019/022 — doc
`documentacion/api/admin/002-patch-admin-orders-id-status.md`).

`markPaid` ("Registrar pago") NO cambia en esta propuesta — su endpoint
es `POST /admin/orders/:id/confirm-payment` y es el siguiente ciclo.

Qué cambia para el dueño:

- Cada avance **vuelve del servidor**: `statusChangedAt` re-sellado es
  lo que ordena el carril — el pedido movido cae al fondo de su nuevo
  carril con la hora real del backend, no la del teléfono.
- **409 = el pedido ya cambió** (carrera perdida, estado viejo):
  toast "ya cambió" + resync automático de la cola. Nunca se muestra el
  `message` inglés del servidor.
- La cancelación sale de la cola al historial **solo si el backend la
  aceptó** — si llega 409 el detalle NO hace pop y avisa.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart` | `patchOrderStatus(orderId, {to, cancelReason})` |
| `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart` | implementa el PATCH → `AdminOrderModel` |
| `lib/features/admin/domain/failures/admin_failure.dart` | `AdminConflictFailure` (409 con `errorCode`) |
| `lib/features/admin/domain/repositories/i_admin_repository.dart` | `updateOrderStatus(orderId, {to, cancelReason})` |
| `lib/features/admin/data/repositories/admin_repository_impl.dart` | impl + `_mapFailure` distingue 409 |
| `lib/features/admin/domain/use_cases/update_admin_order_status_use_case.dart` | **nuevo** — use case delgado |
| `lib/core/di/setup_di.dart` | registra el use case + inyecta en cubit |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | `advanceOrder`/`cancelOrder` remotos → `Future<AdminFailure?>`; `_mutateRemote` núcleo; `markPaid` sigue local |
| `lib/features/admin/presentation/widgets/admin_order_action.dart` | `runAdminOrderAction` — toast éxito solo si no hay failure; toast error por tipo |
| `lib/features/admin/presentation/screens/admin_order_detail_screen.dart` | `_confirmCancel` — failure → toast error + NO pop |
| `lib/l10n/app_es.arb` | 2 strings nuevas (ver §9) + `flutter gen-l10n` |
| `test/features/admin/...` | datasource/repo/use-case/cubit/screen + fixtures |

---

## 1. `i_admin_remote_datasource.dart` (existente — actualización)

**Ruta:** `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart`

**Después** (agregar al final de la clase abstracta):

```dart
  /// PATCH /admin/orders/:id/status (§040 — backend §022): mueve el
  /// pedido por la matriz de 5 estados (`to`: confirmed | preparing |
  /// ready | done | cancelled). `cancelReason` solo viaja con
  /// `to='cancelled'`. Devuelve la vista admin completa con
  /// `statusChangedAt` re-sellado — el reloj de la cola lo pone el
  /// servidor. El 409 sale como ServerException con errorCode
  /// (INVALID_STATUS_TRANSITION | PAYMENT_NOT_SETTLED).
  Future<AdminOrderModel> patchOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  });
```

## 2. `admin_remote_datasource_impl.dart` (existente — actualización)

**Ruta:** `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart`

**Después** (agregar al final de la clase):

```dart
  @override
  Future<AdminOrderModel> patchOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  }) async {
    final response = await _networkService.patch(
      '/admin/orders/$orderId/status',
      body: {
        'to': to,
        if (cancelReason != null) 'cancelReason': cancelReason,
      },
    );
    return AdminOrderModel.fromJson(response as Map<String, dynamic>);
  }
```

## 3. `admin_failure.dart` (existente — actualización)

**Ruta:** `lib/features/admin/domain/failures/admin_failure.dart`

**Después** (agregar al final del archivo):

```dart
/// 409 — conflicto de estado del backend §022: `INVALID_STATUS_TRANSITION`
/// (transición fuera de la matriz o carrera perdida — el pedido ya
/// cambió server-side) y `PAYMENT_NOT_SETTLED` (el avance exigía pago
/// saldado). `errorCode` viaja para logging/telemetría; la UI solo
/// distingue conflicto vs. resto para su toast.
final class AdminConflictFailure extends AdminFailure {
  const AdminConflictFailure(this.errorCode);

  /// INVALID_STATUS_TRANSITION | PAYMENT_NOT_SETTLED | otros futuros.
  final String errorCode;

  @override
  List<Object?> get props => [errorCode];
}
```

## 4. `i_admin_repository.dart` (existente — actualización)

**Ruta:** `lib/features/admin/domain/repositories/i_admin_repository.dart`

**Después** (agregar al final de la clase abstracta):

```dart
  /// PATCH /admin/orders/:id/status (§040): `to` es el estado destino
  /// en inglés del backend (confirmed|preparing|ready|done|cancelled);
  /// `cancelReason` solo con `cancelled`. Devuelve la entidad completa
  /// con `statusChangedAt` re-sellado.
  Future<Either<AdminFailure, AdminOrder>> updateOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  });
```

## 5. `admin_repository_impl.dart` (existente — actualización)

**Ruta:** `lib/features/admin/data/repositories/admin_repository_impl.dart`

**Después** — dos fragmentos:

a) Agregar método tras `getOrderDetail`:

```dart
  @override
  Future<Either<AdminFailure, AdminOrder>> updateOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  }) => _guard(
    () => _remoteDataSource.patchOrderStatus(
      orderId,
      to: to,
      cancelReason: cancelReason,
    ),
  );
```

b) `_mapFailure` distingue el 409:

```dart
  AdminFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const AdminOfflineFailure();
    if (e is ServerException && e.statusCode == 409) {
      return AdminConflictFailure(e.errorCode ?? 'CONFLICT');
    }
    return AdminServerFailure(e.message);
  }
```

## 6. `update_admin_order_status_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/domain/use_cases/update_admin_order_status_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// SOLID (SRP): PATCH /admin/orders/:id/status — la única puerta del
/// dominio para mover un pedido por la matriz §022 (avance o
/// cancelación). El `to` llega ya resuelto desde el cubit (inglés,
/// contrato backend); el use case no conoce la matriz — solo reenvía
/// y deja el 409 al repository.
class UpdateAdminOrderStatusUseCase {
  const UpdateAdminOrderStatusUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(
    String orderId, {
    required String to,
    String? cancelReason,
  }) => _repository.updateOrderStatus(
    orderId,
    to: to,
    cancelReason: cancelReason,
  );
}
```

## 7. `setup_di.dart` (existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

a) Import nuevo junto a los otros use cases admin:

```dart
import '../../features/admin/domain/use_cases/update_admin_order_status_use_case.dart';
```

b) Registro tras `GetAdminOrderDetailUseCase` + inyección en el cubit:

```dart
  locator.registerLazySingleton<UpdateAdminOrderStatusUseCase>(
    () => UpdateAdminOrderStatusUseCase(locator()),
  );
  locator.registerLazySingleton<AdminQueueCubit>(
    () => AdminQueueCubit(
      loadQueue: locator(),
      getOrderDetail: locator(),
      updateOrderStatus: locator(),
    ),
  );
```

## 8. `admin_queue_cubit.dart` (existente — actualización)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_cubit.dart`

a) Constructor — tercer use case:

```dart
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({
    required this._loadQueue,
    required this._getOrderDetail,
    required this._updateOrderStatus,
  }) : super(const AdminQueueState());

  final LoadAdminQueueUseCase _loadQueue;
  final GetAdminOrderDetailUseCase _getOrderDetail;
  final UpdateAdminOrderStatusUseCase _updateOrderStatus;
```

b) `advanceOrder` — remoto, devuelve `AdminFailure?`:

```dart
  /// Avanza un paso en la matriz §022: PATCH /admin/orders/:id/status.
  /// Las puertas de cliente se conservan como no-op temprano (la matriz
  /// real la exige el backend con 409 — si el estado local estaba viejo
  /// el conflicto resincroniza la cola). Devuelve null en éxito/no-op o
  /// la Failure — la UI elige su toast (convención OrdersCubit §027).
  Future<AdminFailure?> advanceOrder(String id) =>
      _mutateRemote(id, (order) {
        if (order.isTerminal || order.awaitsWebhook) return null;
        if (order.status == OrderStatus.received &&
            order.serviceType == AdminServiceType.pickup &&
            order.paymentStatus != OrderPaymentStatus.paid) {
          return null;
        }
        return switch (order.status) {
          OrderStatus.received => 'confirmed',
          OrderStatus.confirmed => 'preparing',
          OrderStatus.preparing => 'ready',
          OrderStatus.ready => 'done',
          OrderStatus.done || OrderStatus.cancelled => null,
        };
      });
```

c) `cancelOrder` — remoto con `cancelReason`:

```dart
  /// Cancela un pedido no-terminal: PATCH {to: 'cancelled',
  /// cancelReason?} — el motivo (español, user-facing) viaja al
  /// detalle del historial del cliente. El backend además tumba un
  /// pago pending en la misma transacción (§022).
  Future<AdminFailure?> cancelOrder(String id, {String? reason}) {
    final trimmed = reason?.trim();
    return _mutateRemote(
      id,
      (order) => order.isTerminal ? null : 'cancelled',
      cancelReason: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }
```

d) Núcleo `_mutateRemote` (reemplaza el rol de `_mutateOrder` para estas
dos operaciones — `markPaid` conserva el viejo hasta §041):

```dart
  /// Núcleo de las mutaciones de status (§040): busy por pedido +
  /// resolución del `to` en cliente (null = no-op local) + el PATCH
  /// real. En éxito el pedido que devuelve el backend REEMPLAZA al
  /// local — `statusChangedAt` re-sellado ordena el carril nuevo —
  /// conservando los ítems hidratados si la respuesta los trae sin
  /// modifiers (vista de listado). `cancelled` migra al frente del
  /// historial (los demás terminales se quedan en active hasta el
  /// cierre — el endpoint de status no cierra el día). En falla:
  /// resync silencioso de la cola (el 409 dice que el pedido ya
  /// cambió server-side — convención OrdersCubit.cancelOrder §027).
  Future<AdminFailure?> _mutateRemote(
    String id,
    String? Function(AdminOrder order) resolveTo, {
    String? cancelReason,
  }) async {
    if (state.busyOrderIds.contains(id)) return null;
    final current = state.orderById(id);
    final to = current == null ? null : resolveTo(current);
    if (to == null) return null;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, id}));
    try {
      final result = await _updateOrderStatus(
        id,
        to: to,
        cancelReason: cancelReason,
      );
      if (isClosed) return null;
      return result.fold(
        (failure) {
          unawaited(load());
          return failure;
        },
        (updated) {
          final hydrated = _preserveHydrated(updated);
          if (updated.status == OrderStatus.cancelled) {
            emit(
              state.copyWith(
                active: state.active.where((o) => o.id != id).toList(),
                history: [
                  hydrated,
                  ...state.history.where((o) => o.id != id),
                ],
              ),
            );
          } else {
            emit(
              state.copyWith(
                active: [
                  for (final o in state.active) o.id == id ? hydrated : o,
                ],
                history: [
                  for (final o in state.history) o.id == id ? hydrated : o,
                ],
              ),
            );
          }
          return null;
        },
      );
    } finally {
      if (!isClosed && state.busyOrderIds.contains(id)) {
        emit(state.copyWith(busyOrderIds: {...state.busyOrderIds}..remove(id)));
      }
    }
  }
```

e) `_preserveHydratedItems` se refactoriza a núcleo por-orden (mismo
criterio, reutilizado por load/refreshOrder/mutaciones):

```dart
  /// Núcleo por-orden: si el payload nuevo llega con `modifiers`
  /// vacíos (vista de listado / PATCH §040) pero la copia previa ya
  /// los tiene (detalle §039), conserva los ítems hidratados.
  AdminOrder _preserveHydrated(AdminOrder incoming) {
    final prev = state.orderById(incoming.id);
    return prev != null &&
            prev.items.any((i) => i.modifiers.isNotEmpty) &&
            !incoming.items.any((i) => i.modifiers.isNotEmpty)
        ? incoming.copyWith(items: prev.items)
        : incoming;
  }

  List<AdminOrder> _preserveHydratedItems(List<AdminOrder> incoming) =>
      [for (final o in incoming) _preserveHydrated(o)];
```

f) Import nuevo: `import 'dart:async' show unawaited;` +
`import '../../domain/failures/admin_failure.dart';`

g) `markPaid` queda igual por ahora — su doc comenta que sigue local
hasta el ciclo de `confirm-payment` (§041).

## 9. `admin_order_action.dart` — toast por resultado (existente)

**Ruta:** `lib/features/admin/presentation/widgets/admin_order_action.dart`

**Después** — `runAdminOrderAction` devuelve el resultado y muestra el
toast correcto (éxito solo si `failure == null`; conflicto → texto
"ya cambió"; resto → genérico):

```dart
Future<void> runAdminOrderAction(
  BuildContext context,
  AdminOrder order,
  AdminOrderAction action,
) async {
  final cubit = context.read<AdminQueueCubit>();
  final failure = switch (action) {
    AdminOrderAction.markPaid => await cubit.markPaid(order.id),
    _ => await cubit.advanceOrder(order.id),
  };
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  if (failure != null) {
    AppToast.error(
      context,
      failure is AdminConflictFailure
          ? l10n.adminToastActionRejected
          : l10n.adminToastActionFailed,
    );
    return;
  }
  AppToast.success(context, switch (action) {
    AdminOrderAction.confirm => l10n.adminToastOrderConfirmed,
    AdminOrderAction.prepare => l10n.adminToastOrderPreparing,
    AdminOrderAction.markReady => l10n.adminToastOrderReady,
    AdminOrderAction.markPaid => l10n.adminToastPaymentConfirmed,
    AdminOrderAction.markDone => l10n.adminToastOrderDone,
  });
}
```

Nota: `markPaid` sigue devolviendo `Future<void>` local en §040 — el
switch lo tipa como `Future<dynamic>`; cuando §041 lo haga remoto se
unifica a `AdminFailure?`. Si el lint se queja del tipo heterogéneo,
alternativa: mantener el `switch` de llamadas por caso y capturar el
`AdminFailure?` solo en las ramas de `advanceOrder`.

Import nuevo: `import '../../domain/failures/admin_failure.dart';`
Verificar `AppToast.error` existe (si no, usar `AppToast.info` — el
implementador confirma la variante real del widget).

## 10. `admin_order_detail_screen.dart` — cancelación real (existente)

**Ruta:** `lib/features/admin/presentation/screens/admin_order_detail_screen.dart`

**Después** — `_confirmCancel`: failure → toast de error y el detalle
NO se cierra (el pedido no se canceló); éxito → toast + pop como hoy:

```dart
  Future<void> _confirmCancel(BuildContext context) async {
    final reason = await showAdminOrderCancelDialog(context);
    if (reason == null || !context.mounted) return;
    final failure = await context.read<AdminQueueCubit>().cancelOrder(
      widget.order.id,
      reason: reason,
    );
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (failure != null) {
      AppToast.error(
        context,
        failure is AdminConflictFailure
            ? l10n.adminToastActionRejected
            : l10n.adminToastActionFailed,
      );
      return;
    }
    AppToast.info(context, l10n.orderCancelledToast);
    context.pop();
  }
```

Import nuevo: `import '../../domain/failures/admin_failure.dart';`

## 11. i18n — `app_es.arb` (2 keys nuevas, tras `adminToastOrderReady`)

```json
  "adminToastActionFailed": "No pudimos actualizar el pedido — inténtalo de nuevo",
  "@adminToastActionFailed": {
    "description": "Toast de error genérico al avanzar/cancelar un pedido admin (offline/5xx — convención ordersCancelError §027)"
  },
  "adminToastActionRejected": "El pedido ya cambió — la cola se actualizó",
  "@adminToastActionRejected": {
    "description": "Toast cuando el backend rechaza la mutación con 409 (INVALID_STATUS_TRANSITION/PAYMENT_NOT_SETTLED — la cola ya se resincronizó sola; el mensaje del servidor viene en inglés y nunca se muestra)"
  },
```

Ejecutar `flutter gen-l10n`.

## 12. Tests

| Archivo | Casos nuevos |
|---------|--------------|
| `test/features/admin/data/datasources/admin_remote_datasource_impl_test.dart` (nuevo o extender) | PATCH con `to` correcto; `cancelReason` viaja solo cuando viene; parse del 200 |
| `test/features/admin/data/repositories/admin_repository_impl_test.dart` | 200→Right(entidad); 409 ServerException→AdminConflictFailure con errorCode; 404→ServerFailure; offline→OfflineFailure |
| `test/features/admin/domain/use_cases/update_admin_order_status_use_case_test.dart` | passthrough con `to`/`cancelReason` |
| `test/features/admin/presentation/cubit/admin_queue_cubit_test.dart` | advance 200 reemplaza con statusChangedAt nuevo; cancelled migra a history al frente; respuesta PATCH sin modifiers conserva los hidratados; 409 devuelve ConflictFailure + dispara resync; busy ignora re-entry; gates locales: terminal/awaitWebhook/pickup-sin-pagar = no-op sin HTTP; markPaid sigue funcionando local |
| `test/features/admin/presentation/screens/admin_order_detail_screen_test.dart` | cancel con failure → toast error + pantalla sigue; éxito → pop |
| `test/features/admin/presentation/widgets/admin_order_action_test.dart` (o dentro de queue_screen_test) | failure → NO toast éxito + toast error; conflicto → texto "ya cambió" |
| `test/features/admin/fixtures/admin_order_fixtures.dart` | fixture de respuesta PATCH (mismo shape del detalle, `statusChangedAt` posterior) si hace falta |

---

## Orden de aplicación

1. `admin_failure.dart` → `i_admin_remote_datasource.dart` → `admin_remote_datasource_impl.dart`
2. `i_admin_repository.dart` → `admin_repository_impl.dart`
3. `update_admin_order_status_use_case.dart` → `setup_di.dart`
4. `admin_queue_cubit.dart` (use case + `_mutateRemote` + `_preserveHydrated`)
5. `admin_order_action.dart` + `admin_order_detail_screen.dart` + `app_es.arb` + `flutter gen-l10n`
6. Tests + fixtures
7. `flutter analyze` + `flutter test`

## Fuera de alcance (siguiente ciclo)

- `markPaid` → `POST /admin/orders/:id/confirm-payment` (cobra Y avanza —
  los dos caminos del backend: pickup pendiente→confirmed y
  ready→done). Los íconos de la fila de pago del detalle también.
- `GET/POST /admin/day-close` — `loadDayClosePreview`/`closeDay` siguen
  calculando en cliente.
- SSE/push para que la cola se actualice sola — hoy el resync es por
  visita al tab / pull-to-refresh / post-falla.

---

## Adición post-implementación — fix UX: salida animada + chip que pulsa

Reportado por el usuario en la verificación física: al moverse un
pedido "se va de golpe" — el `ListView` del carril teletransportaba
la card en la emisión. Decisión del usuario (opción escogida):
**sale animado + chip pulsa** — sin navegación automática al carril
destino.

- `admin_queue_lane.dart`: `ListView` → `AnimatedList` con diff por
  id (`_applyOrders` — salientes colapsan+fade ~320ms desde el
  objeto capturado e `IgnorePointer`, entrantes crecen desde el
  tope, ítems en sitio solo refrescan; blindaje anti-reorden).
  El mensaje de carril vacío pasa a capa en crossfade BAJO la
  lista (solo monta con el carril vacío — opacidad 0 no saca un
  widget del árbol ni de los finders).
- `admin_lane_strip.dart`: `_LaneChip` → StatefulWidget — pulsa
  (chip 1→1.06→1 + badge 1→1.22→1, ~450ms) cuando `count` cambia
  en `didUpdateWidget`.
- Test nuevo: la card sigue en el árbol a mitad del colapso
  (~80ms) — no teletransporta. Finders `ListView`→`AnimatedList`.
- Revisor §040: APROBADO CON OBSERVACIONES (0 CRITICO/IMPORTANTE);
  correcciones aplicadas — comentario duplicado en test,
  `IgnorePointer` en la saliente, guardia de orden.
