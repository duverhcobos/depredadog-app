# Propuesta: Cocina cierra el loop — confirm-payment + day-close reales (App §041)

Los últimos dos puntos provisionales de Cocina dejan el cliente local:
**"Registrar pago"** (`markPaid`, hoy muta solo el estado) pasa a
`POST /admin/orders/:id/confirm-payment` — el backend cobra Y avanza
en el mismo hecho atómico (pending+presencial+pickup→confirmed,
ready→done, otros estados solo cobran; idempotente). Y el **cierre
de caja** deja de calcularse en mocks: `GET /admin/day-close`
alimenta el preview y `POST /admin/day-close` ejecuta el cierre que
archiva los `done` al historial.

Misma cadena de las 038-040: `datasource → repository (_guard Either,
409→AdminConflictFailure con errorCode) → use case → cubit singleton`
— ninguna decisión de negocio nueva: las matrices ya existen, solo se
reemplaza el transporte.

Contratos: `documentacion/api/admin/003-post-admin-orders-id-confirm-payment.md`,
`006-get-admin-day-close.md`, `007-post-admin-day-close.md`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/data/models/admin_day_close_model.dart` | **nuevo** — parse del snapshot del cierre (normaliza `gateway`→`nequi` como AdminOrderModel) |
| `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart` | +`confirmPayment`, `fetchDayClose`, `postDayClose` |
| `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart` | implementa los 3 endpoints |
| `lib/features/admin/domain/repositories/i_admin_repository.dart` | +`confirmOrderPayment`, `getDayClosePreview`, `closeDay` |
| `lib/features/admin/data/repositories/admin_repository_impl.dart` | implementa los 3 (mismo `_guard`/`_mapFailure`) |
| `lib/features/admin/domain/use_cases/confirm_admin_order_payment_use_case.dart` | **nuevo** |
| `lib/features/admin/domain/use_cases/load_admin_day_close_use_case.dart` | **nuevo** |
| `lib/features/admin/domain/use_cases/close_admin_day_use_case.dart` | **nuevo** |
| `lib/core/di/setup_di.dart` | registra los 3 use cases + inyección en el cubit |
| `lib/features/admin/presentation/cubit/admin_queue_state.dart` | +`dayCloseFailed` (el preview fallido no puede quedar en spinner eterno) |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | `markPaid` remoto, `loadDayClosePreview`/`closeDay` remotos; extrae `_replaceOrder` compartido con `_mutateRemote` |
| `lib/features/admin/presentation/widgets/admin_order_action.dart` | `markPaid` entra al canal de Failure (mismos toasts por tipo) |
| `lib/features/admin/presentation/screens/admin_day_close_screen.dart` | error del preview (vista + Reintentar) y error del cierre (toast + se queda) |
| `lib/l10n/app_es.arb` | 3 strings nuevos + `flutter gen-l10n` |
| tests | model, datasource, repository, 3 use cases, cubit (markPaid remoto + day-close), pantalla day-close (error/retry/falla de cierre), fixtures |

---

## 1. admin_day_close_model.dart (archivo nuevo)

**Ruta:** `lib/features/admin/data/models/admin_day_close_model.dart`

```dart
import '../../domain/entities/admin_day_close.dart';

/// JSON del cierre de caja (GET/POST /admin/day-close — backend
/// §022): orderCount/totalAmount/byMethod[]/cancelled*. El POST
/// además devuelve id/closedAt/note que la UI no consume (el
/// resumen es el snapshot de éxito).
/// `byMethod[].method` llega crudo del pago: 'gateway' se
/// normaliza a 'nequi' — la misma regla de AdminOrderModel (§038)
/// para que la pantalla lo pinte "Nequi", no "gateway".
class AdminDayCloseModel extends AdminDayClose {
  AdminDayCloseModel.fromJson(Map<String, dynamic> json)
    : super(
        orderCount: json['orderCount'] as int? ?? 0,
        totalAmount: json['totalAmount'] as int? ?? 0,
        byMethod: [
          for (final m in (json['byMethod'] as List? ?? const []))
            AdminDayCloseMethod(
              method: m['method'] == 'gateway'
                  ? 'nequi'
                  : (m['method'] as String? ?? 'unknown'),
              count: m['count'] as int? ?? 0,
              amount: m['amount'] as int? ?? 0,
            ),
        ],
        cancelledCount: json['cancelledCount'] as int? ?? 0,
        cancelledAmount: json['cancelledAmount'] as int? ?? 0,
      );
}
```

## 2. IAdminRemoteDataSource (archivo existente)

**Ruta:** `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart`

**Después** (se agrega al final de la interfaz, tras `patchOrderStatus`):

```dart
  /// POST /admin/orders/:id/confirm-payment (§041 — backend §022):
  /// cobra el pago pending (claim atómico, idempotente — un pago ya
  /// `paid` responde la misma orden) y AVANZA la orden cuando el
  /// estado lo amerita: pending+presencial+pickup→confirmed,
  /// ready→done. El 409 sale como ServerException con errorCode
  /// (PAYMENT_NOT_CONFIRMABLE).
  Future<AdminOrderModel> confirmPayment(String orderId);

  /// GET /admin/day-close (§041 — backend §022): preview de solo
  /// lectura — los terminales (`done`+`cancelled`) aún sin cerrar.
  Future<AdminDayCloseModel> fetchDayClose();

  /// POST /admin/day-close (§041 — backend §022): ejecuta el cierre
  /// atómico — crea el registro, estampa `day_close_id` en los
  /// terminales y devuelve el snapshot persistido.
  Future<AdminDayCloseModel> postDayClose();
}
```

(`import '../models/admin_day_close_model.dart';` en el encabezado.)

## 3. AdminRemoteDataSourceImpl (archivo existente)

**Ruta:** `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart`

**Después** (tras `patchOrderStatus`, misma forma que los demás):

```dart
  @override
  Future<AdminOrderModel> confirmPayment(String orderId) async {
    final json = await _network.post('/admin/orders/$orderId/confirm-payment');
    return AdminOrderModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<AdminDayCloseModel> fetchDayClose() async {
    final json = await _network.get('/admin/day-close');
    return AdminDayCloseModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<AdminDayCloseModel> postDayClose() async {
    final json = await _network.post('/admin/day-close');
    return AdminDayCloseModel.fromJson(json as Map<String, dynamic>);
  }
```

## 4. IAdminRepository (archivo existente)

**Ruta:** `lib/features/admin/domain/repositories/i_admin_repository.dart`

**Después** (tras `updateOrderStatus`):

```dart
  /// POST /admin/orders/:id/confirm-payment (§041): cobra y avanza
  /// (pending+presencial+pickup→confirmed, ready→done); idempotente
  /// en `paid`. Devuelve la entidad completa.
  Future<Either<AdminFailure, AdminOrder>> confirmOrderPayment(
    String orderId,
  );

  /// GET /admin/day-close (§041): preview de terminales sin cerrar.
  Future<Either<AdminFailure, AdminDayClose>> getDayClosePreview();

  /// POST /admin/day-close (§041): cierra el periodo — devuelve el
  /// snapshot persistido del servidor.
  Future<Either<AdminFailure, AdminDayClose>> closeDay();
}
```

(`import '../entities/admin_day_close.dart';` en el encabezado.)

## 5. AdminRepositoryImpl (archivo existente)

**Ruta:** `lib/features/admin/data/repositories/admin_repository_impl.dart`

**Después:**

```dart
  @override
  Future<Either<AdminFailure, AdminOrder>> confirmOrderPayment(
    String orderId,
  ) => _guard(() => _remote.confirmPayment(orderId));

  @override
  Future<Either<AdminFailure, AdminDayClose>> getDayClosePreview() =>
      _guard(() => _remote.fetchDayClose());

  @override
  Future<Either<AdminFailure, AdminDayClose>> closeDay() =>
      _guard(() => _remote.postDayClose());
```

(`import '../../domain/entities/admin_day_close.dart';` — el mismo
`_guard`/`_mapFailure` de §040 cubre 409→AdminConflictFailure con
`errorCode`, offline→AdminOfflineFailure y genérico→AdminServerFailure
sin código nuevo.)

## 6-8. Use cases (archivos nuevos — espejo del patrón §038-040)

**Ruta:** `lib/features/admin/domain/use_cases/confirm_admin_order_payment_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// "Registrar pago" real (§041): POST confirm-payment — cobra y
/// avanza la orden en el mismo hecho del backend.
class ConfirmAdminOrderPaymentUseCase {
  const ConfirmAdminOrderPaymentUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(String orderId) =>
      _repository.confirmOrderPayment(orderId);
}
```

**Ruta:** `lib/features/admin/domain/use_cases/load_admin_day_close_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_day_close.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Preview del cierre (§041): GET /admin/day-close — solo lectura.
class LoadAdminDayCloseUseCase {
  const LoadAdminDayCloseUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminDayClose>> call() =>
      _repository.getDayClosePreview();
}
```

**Ruta:** `lib/features/admin/domain/use_cases/close_admin_day_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_day_close.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Cierre del periodo (§041): POST /admin/day-close — atómico.
class CloseAdminDayUseCase {
  const CloseAdminDayUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminDayClose>> call() =>
      _repository.closeDay();
}
```

## 9. setup_di.dart (archivo existente)

**Ruta:** `lib/core/di/setup_di.dart`

**Después** — tras los use cases existentes de admin:

```dart
  locator.registerLazySingleton<ConfirmAdminOrderPaymentUseCase>(
    () => ConfirmAdminOrderPaymentUseCase(locator()),
  );
  locator.registerLazySingleton<LoadAdminDayCloseUseCase>(
    () => LoadAdminDayCloseUseCase(locator()),
  );
  locator.registerLazySingleton<CloseAdminDayUseCase>(
    () => CloseAdminDayUseCase(locator()),
  );
```

y el cubit pasa a 6 dependencias:

```dart
  locator.registerLazySingleton<AdminQueueCubit>(
    () => AdminQueueCubit(
      loadQueue: locator(),
      getOrderDetail: locator(),
      updateOrderStatus: locator(),
      confirmOrderPayment: locator(),
      loadDayClose: locator(),
      closeDay: locator(),
    ),
  );
```

## 10. AdminQueueState (archivo existente)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_state.dart`

**Después** — campo nuevo junto a `dayClose`/`dayCloseBusy`:

```dart
  /// El preview del cierre FALLÓ (§041 — GET /admin/day-close):
  /// sin este flag la pantalla quedaba en spinner eterno — ahora
  /// muestra error + Reintentar (misma convención de la cola).
  final bool dayCloseFailed;
```

(`this.dayCloseFailed = false` en el ctor, `bool? dayCloseFailed` en
copyWith, `dayCloseFailed` en props.)

## 11. AdminQueueCubit (archivo existente)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_cubit.dart`

**Antes:** `markPaid` es `_mutateOrder` local; `loadDayClosePreview`
calcula en cliente; `closeDay` archiva en cliente. `_mutateOrder`
queda sin uso y se elimina.

**Después:**

```dart
  final ConfirmAdminOrderPaymentUseCase _confirmOrderPayment;
  final LoadAdminDayCloseUseCase _loadDayClose;
  final CloseAdminDayUseCase _closeDay;
```

(añadidas al ctor por nombre, mismo estilo que las otras tres.)

```dart
  /// "Registrar pago" — POST /admin/orders/:id/confirm-payment
  /// (§041, backend §022): el servidor cobra Y avanza en el mismo
  /// hecho atómico (pending+presencial+pickup→confirmed, ready→done;
  /// idempotente en `paid`). Las puertas locales se conservan como
  /// no-op — terminal, Nequi (el webhook manda, §036) y pago ya
  /// saldado: el backend responde 200-idempotente pero no gastamos
  /// el request. En falla: resync silencioso de la cola.
  Future<AdminFailure?> markPaid(String id) {
    final current = state.orderById(id);
    if (current == null ||
        current.isTerminal ||
        current.paymentMethod == AdminPaymentMethod.nequi ||
        current.paymentStatus == OrderPaymentStatus.paid) {
      return Future.value();
    }
    return _mutatePayment(id);
  }

  /// Gemelo de `_mutateRemote` para el claim de pago: misma busy
  /// por pedido + el mismo fold (falla → resync; éxito → la entidad
  /// devuelta reemplaza con `_preserveHydrated`). Comparten
  /// `_replaceOrder` — el POST nunca devuelve `cancelled` pero el
  /// helper cubre el caso igual que el PATCH.
  Future<AdminFailure?> _mutatePayment(String id) async {
    if (state.busyOrderIds.contains(id)) return null;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, id}));
    try {
      final result = await _confirmOrderPayment(id);
      if (isClosed) return null;
      final outcome = result.fold(
        (failure) {
          unawaited(load());
          return failure;
        },
        (updated) {
          _replaceOrder(updated);
          return null;
        },
      );
      return outcome;
    } finally {
      if (!isClosed && state.busyOrderIds.contains(id)) {
        emit(
          state.copyWith(busyOrderIds: {...state.busyOrderIds}..remove(id)),
        );
      }
    }
  }
```

`_mutateRemote` refactoriza su rama de éxito al helper compartido
(sin cambio de comportamiento — el diff cancelado→history ya vive ahí):

```dart
  /// La entidad devuelta por PATCH/POST REEMPLAZA a la local en
  /// ambos buckets — `statusChangedAt` re-sellado ordena el carril
  /// nuevo; `cancelled` migra al frente del historial.
  void _replaceOrder(AdminOrder updated) {
    final hydrated = _preserveHydrated(updated);
    if (updated.status == OrderStatus.cancelled) {
      emit(
        state.copyWith(
          active: state.active.where((o) => o.id != updated.id).toList(),
          history: [
            hydrated,
            ...state.history.where((o) => o.id != updated.id),
          ],
        ),
      );
    } else {
      emit(
        state.copyWith(
          active: [
            for (final o in state.active) o.id == updated.id ? hydrated : o,
          ],
          history: [
            for (final o in state.history) o.id == updated.id ? hydrated : o,
          ],
        ),
      );
    }
  }
```

```dart
  /// Preview del cierre — GET /admin/day-close (§041): el servidor
  /// calcula los terminales sin cerrar; falla → dayCloseFailed (la
  /// pantalla muestra error + Reintentar, no spinner eterno).
  Future<void> loadDayClosePreview() async {
    emit(state.copyWith(dayCloseFailed: false));
    final result = await _loadDayClose();
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(dayCloseFailed: true)),
      (summary) => emit(state.copyWith(dayClose: () => summary)),
    );
  }

  /// Cierre del periodo — POST /admin/day-close (§041): el snapshot
  /// del servidor queda en `dayClose` como resumen de éxito y los
  /// `done` salen del carril Entregado al FRENTE del historial (el
  /// más reciente primero — la cola por carril los tenía asc). La
  /// animación de salida del AnimatedList juega sola: el diff ve a
  /// todos irse de una. En falla devuelve null — la pantalla toastea
  /// y se queda en el preview.
  Future<AdminDayClose?> closeDay() async {
    if (state.dayCloseBusy) return null;
    emit(state.copyWith(dayCloseBusy: true));
    try {
      final result = await _closeDay();
      if (isClosed) return null;
      return result.fold(
        (_) => null,
        (summary) {
          final closed = [
            for (final o in state.active)
              if (o.status == OrderStatus.done) o,
          ];
          emit(
            state.copyWith(
              active: [
                for (final o in state.active)
                  if (o.status != OrderStatus.done) o,
              ],
              history: [...closed.reversed, ...state.history],
              dayClose: () => summary,
            ),
          );
          return summary;
        },
      );
    } finally {
      if (!isClosed && state.dayCloseBusy) {
        emit(state.copyWith(dayCloseBusy: false));
      }
    }
  }
```

## 12. admin_order_action.dart (archivo existente)

**Ruta:** `lib/features/admin/presentation/widgets/admin_order_action.dart`

**Antes:**

```dart
    case AdminOrderAction.markPaid:
      await cubit.markPaid(order.id);
```

**Después:** el cobro entra al mismo canal de Failure — conflicto
409 (PAYMENT_NOT_CONFIRMABLE) → "el pedido ya cambió"; offline/5xx →
el toast de pago específico `adminToastPaymentFailed`:

```dart
    case AdminOrderAction.markPaid:
      failure = await cubit.markPaid(order.id);
```

y la rama de falla distingue el toast de pago:

```dart
  if (failure != null) {
    AppToast.error(
      context,
      failure is AdminConflictFailure
          ? l10n.adminToastActionRejected
          : action == AdminOrderAction.markPaid
              ? l10n.adminToastPaymentFailed
              : l10n.adminToastActionFailed,
    );
    return;
  }
```

(La fila de pago del detalle y el footer ya entran por
`runAdminOrderAction` — heredan el comportamiento sin tocarlos.)

## 13. admin_day_close_screen.dart (archivo existente)

**Ruta:** `lib/features/admin/presentation/screens/admin_day_close_screen.dart`

**Antes:** `summary == null` → spinner sin escape; `closeDay()`
fallaba en silencio.

**Después:**

```dart
  Future<void> _confirmClose() async {
    final result = await context.read<AdminQueueCubit>().closeDay();
    if (!mounted) return;
    if (result == null) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.adminToastDayCloseFailed,
      );
      return;
    }
    AppToast.success(
      context,
      AppLocalizations.of(context)!
          .adminToastDayClosed(formatCop(result.totalAmount)),
    );
    setState(() => _result = result);
  }
```

y en el cuerpo, `summary == null` se divide:

```dart
            : LayoutBuilder(
                builder: (context, c) => state.dayCloseFailed
                    ? _DayCloseError(
                        onRetry: () => context
                            .read<AdminQueueCubit>()
                            .loadDayClosePreview(),
                      )
                    : /* el spinner actual, sin cambios */,
              )
```

con `_DayCloseError` (widget privado, misma familia `_QueueError` —
ícono `cloud_off_rounded` + `adminDayCloseLoadError` + OutlinedButton
"Reintentar") acotado a la zona negra como el spinner.

## 14. app_es.arb (archivo existente — 3 strings nuevos)

```json
"adminToastPaymentFailed": "No pudimos registrar el pago — inténtalo de nuevo",
"adminDayCloseLoadError": "No pudimos cargar el cierre",
"adminToastDayCloseFailed": "No pudimos cerrar la caja — inténtalo de nuevo",
```

(los metadatos `@` con su descripción, como el resto del archivo;
después `flutter gen-l10n`.)

## 15. Tests

| Archivo | Cubre |
|---------|-------|
| `test/features/admin/data/models/admin_day_close_model_test.dart` (nuevo) | parse completo; `gateway`→`nequi`; faltantes→ceros |
| `test/features/admin/data/datasources/admin_remote_datasource_impl_test.dart` | los 3 endpoints: verbo/ruta; parse del 200/201 |
| `test/features/admin/data/repositories/admin_repository_impl_test.dart` | confirm-payment 200→Right; 409→Conflict con `PAYMENT_NOT_CONFIRMABLE`; day-close GET/POST→Right; offline→Offline |
| `test/features/admin/domain/use_cases/*_test.dart` (3 nuevos) | passthrough con args correctos |
| `test/features/admin/presentation/cubit/admin_queue_cubit_test.dart` | markPaid: gates no-HTTP (terminal/nequi/paid → `verifyNever`); pickup pendiente → confirmed reemplaza + sale del carril; ready→done QUEDA en active; falla → resync; busy re-entry; loadDayClosePreview Right→dayClose / Left→dayCloseFailed; closeDay: done→frente de history + summary + busy off; falla → null + busy off |
| `test/features/admin/presentation/screens/admin_day_close_screen_test.dart` | preview fallido → error + Reintentar re-pide; cierre falla → toast + sigue en preview; éxito → check + resumen del SERVIDOR |
| `test/features/admin/presentation/screens/admin_queue_screen_test.dart` | "Registrar pago" ahora sí mueve: pickup pendiente → Confirmado con toast + chip pulsa |
| `test/features/admin/fixtures/admin_order_fixtures.dart` | Fake×3 nuevos use cases + `stubConfirmEcho`/`stubDayClose` |

---

## Orden de aplicación

1. Modelo + datasource (interfaz + impl)
2. Repositorio (interfaz + impl)
3. Use cases ×3 + `setup_di.dart`
4. `admin_queue_state.dart` (+`dayCloseFailed`) → `admin_queue_cubit.dart`
5. `admin_order_action.dart` + `admin_day_close_screen.dart` + `app_es.arb` + `flutter gen-l10n`
6. Tests + fixtures
7. `flutter analyze` + `flutter test`

## Adiciones post-implementación (revisor §041)

- **`admin_day_close_screen.dart`**: el CTA "Confirmar cierre" queda
  DESHABILITADO (`onPressed: null`) mientras `summary == null` —
  durante la carga y tras el error del preview. Sin la guardia el
  dueño podía ejecutar un cierre a ciegas (POST real sin haber visto
  el resumen — justo lo que el preview existe para prevenir). Test
  de regresión en `admin_day_close_screen_test.dart` (deshabilitado
  en error → habilitado tras Reintentar).
- Docstrings stale actualizados ("mocks" → integración real) en
  `admin_queue_state.dart`, `admin_day_close.dart`,
  `admin_day_close_screen.dart` y `admin_order_action.dart`.

## Fuera de alcance

- **Campo `note` del cierre** — el backend la acepta (MaxLength 500);
  la pantalla no la pide. Se difiere al siguiente corte de caja si el
  dueño la quiere ("cierre lento por la lluvia").
- **`orders[]` del snapshot en la entidad** — el detalle de pedidos
  archivados existe en el payload pero la pantalla no lo lista hoy;
  queda parseable si se quisiera mostrar después.
- **Listado histórico de cierres** — el backend no lo expone (es
  registro de auditoría en `day_closes`); la pantalla de éxito usa
  el snapshot en memoria.
- **Refresco extra tras el cierre** — el swap local done→history es
  exacto (el servidor cerró precisamente esos pedidos); un `load()`
  adicional sería redundante.
