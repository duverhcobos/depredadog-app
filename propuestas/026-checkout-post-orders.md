# Propuesta: Checkout — confirmar crea el pedido real (POST /orders)

Ciclo 2 de integración del checkout (ver `025-checkout-datos-reales.md` — ciclo 1: direcciones + config del local reales). "Confirmar pedido" deja de ser simulado: persiste el agregado completo en el backend (§015 — `orders` + `order_items` + `order_item_modifiers` + `payments` en una tx, con revalidación de catálogo y precios server-side).

**Alcance:** un solo endpoint — `POST /orders`. El tab Pedidos sigue mock hasta el ciclo 3 (esperado: el pedido recién creado NO aparece allí todavía — vive en el backend).

**Decisiones encuestadas (aprobadas 2026-11-09):**
1. `deliveryLocationLink` **SÍ viaja** aunque hoy sea el link mock — el usuario quiere el plomería probada de punta a punta: cuando llegue geo real el campo ya funciona igual.
2. `clientRequestId` con el **paquete `uuid`**.
3. Fallo del pedido → **fila inline persistente** con el motivo del servidor (opción A). Nota del usuario: **no se trabaja pedido mínimo** (el backend igual lo valida — simplemente no se usa como ejemplo).
4. El tab Pedidos mock tras confirmar está bien — el ciclo 3 lo conecta a `GET /orders`.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/checkout/domain/entities/placed_order.dart` | **nuevo** — entidad de la orden creada |
| `lib/features/checkout/domain/use_cases/create_order_params.dart` | **nuevo** — comando con los ~10 campos del payload + item/modifier inputs |
| `lib/features/checkout/domain/use_cases/create_order_use_case.dart` | **nuevo** — passthrough SRP |
| `lib/features/checkout/data/models/placed_order_model.dart` | **nuevo** — parser del response |
| `lib/features/checkout/domain/failures/checkout_failure.dart` | + `CheckoutOrderRejectedFailure` (4xx con mensaje del servidor) |
| `lib/features/checkout/data/datasources/interfaces/i_checkout_remote_datasource.dart` | + `createOrder` |
| `lib/features/checkout/data/datasources/implementations/checkout_remote_datasource_impl.dart` | + `createOrder` |
| `lib/features/checkout/domain/repositories/i_checkout_repository.dart` | + `createOrder(params)` |
| `lib/features/checkout/data/repositories/checkout_repository_impl.dart` | + `createOrder` (arma el wire map) + `_guard` con mapper por método |
| `lib/features/checkout/presentation/cubit/checkout_state.dart` | + `confirmError` (String? — inline persistente) |
| `lib/features/checkout/presentation/cubit/checkout_cubit.dart` | `confirm()` real: params del state+carrito → use case → fold; `clientRequestId` uuid por instancia; `justSavedAddress` como addressId; no re-guarda en retry; quita el delay mock |
| `lib/features/checkout/presentation/screens/checkout_screen.dart` | fila de error de confirmación sobre el CTA |
| `lib/core/di/setup_di.dart` | `CreateOrderUseCase` lazySingleton + param del factory |
| `lib/l10n/app_es.arb` | + `checkoutOrderFailed` + `checkoutOrderOffline` → `flutter gen-l10n` |
| `pubspec.yaml` | + `uuid` |
| `test/features/checkout/domain/use_cases/create_order_use_case_test.dart` | **nuevo** |
| `test/features/checkout/data/repositories/checkout_repository_impl_test.dart` | + casos createOrder |
| `test/features/checkout/presentation/cubit/checkout_cubit_test.dart` | confirm real: payload, retry idempotente, errores |
| `test/features/checkout/presentation/screens/checkout_screen_test.dart` | fila de error + diálogo sigue igual |

## Contrato (backend §015 — `CreateOrderDto`)

```json
{
  "serviceType": "pickup|delivery",
  "items": [{"productId": "uuid", "quantity": 2,
             "modifiers": [{"optionId": "uuid", "action": "added|removed",
                            "replacesOptionId": "uuid?"}]}],
  "addressId": "uuid?",           // XOR newAddress — domicilio guardada
  "newAddress": {"landmark": "…", "neighborhood": "…?"},  // domicilio nueva no guardada
  "contactPhone": "3XXXXXXXXX",   // delivery exige
  "paymentMethod": "cash|transfer",
  "payerPhone": "3XXXXXXXXX",     // transfer exige
  "notes": "…?",
  "clientRequestId": "uuid"       // idempotencia — índice único (customer, id)
}
```

Response 201 → `OrderResponseDto` (`id`, `orderNumber`, `status`, `total`, `items`, `payment`, …). Errores: 400 validación · 409 reglas (local cerrado, agotado, reemplazo inválido, pickup+cash) · 401.

**Mapeo UI → wire:** `nequi`→`transfer` (+`payerPhone`=nequiPhone) · `onDelivery`→`cash` · `justSavedAddress?.id ?? addressId` (si ≠`'new'`) · `'new'`→`newAddress{landmark,neighborhood?}` · `notes`=note · `deliveryLocationLink` viaja cuando está puesto (hoy el link mock — el pipe queda probado para geo real, decisión #1).

---

## 1. `placed_order.dart` (archivo nuevo)

**Ruta:** `lib/features/checkout/domain/entities/placed_order.dart`

```dart
import 'package:equatable/equatable.dart';

/// Orden creada por POST /orders (§026 — backend 015). El diálogo de
/// éxito NO muestra el consecutivo (§022b — no revelar el volumen del
/// negocio); `id`/`orderNumber` quedan para el detalle real del ciclo 3.
class PlacedOrder extends Equatable {
  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
  });

  final String id;

  /// Consecutivo diario `#N` (visible solo para el local hoy).
  final int orderNumber;

  /// 'pending' al nacer.
  final String status;

  /// Total cobrado ya validado server-side (snapshot de la orden).
  final int total;

  @override
  List<Object?> get props => [id, orderNumber, status, total];
}
```

## 2. `create_order_params.dart` (archivo nuevo)

**Ruta:** `lib/features/checkout/domain/use_cases/create_order_params.dart`

```dart
/// Comando de POST /orders (§026 — backend 015). Los ~10 campos del
/// payload en un objeto valor: la firma de repo/use-case queda en un
/// parámetro. Dominio puro — la serialización JSON vive en data/
/// (el repo impl arma el Map, igual que saveAddress).
class CreateOrderParams {
  const CreateOrderParams({
    required this.serviceType,
    required this.paymentMethod,
    required this.items,
    required this.clientRequestId,
    this.addressId,
    this.newLandmark,
    this.newNeighborhood,
    this.contactPhone,
    this.deliveryLocationLink,
    this.payerPhone,
    this.notes,
  });

  /// 'pickup' | 'delivery' — el enum del backend.
  final String serviceType;

  /// 'cash' | 'transfer' — el Nequi de la UI viaja como 'transfer'.
  final String paymentMethod;

  final List<OrderItemInput> items;

  /// Idempotencia (§015): un uuid por instancia de checkout; un
  /// reintento responde la orden ya creada en vez de duplicarla.
  final String clientRequestId;

  /// Domicilio con dirección guardada — la seleccionada o la recién
  /// persistida por "Guardar esta ubicación" (justSavedAddress).
  final String? addressId;

  /// Domicilio con "Nueva ubicación" no guardada — landmark exigido,
  /// neighborhood opcional (XOR con addressId).
  final String? newLandmark;
  final String? newNeighborhood;

  /// §024 — celular de quién recibe (delivery lo exige).
  final String? contactPhone;

  /// Pin de Google Maps adjunto al pedido (§022d — hoy el link mock;
  /// viaja para que el pipe quede probado hasta la geo real).
  final String? deliveryLocationLink;

  /// §024 — celular que paga cuando transfer (Nequi).
  final String? payerPhone;

  final String? notes;
}

/// Ítem del pedido — espejo de OrderItemDto del backend (sin notes:
/// el carrito no tiene nota por ítem).
class OrderItemInput {
  const OrderItemInput({
    required this.productId,
    required this.quantity,
    this.modifiers = const [],
  });

  final String productId;
  final int quantity;
  final List<OrderModifierInput> modifiers;
}

/// Modificador del ítem — espejo de OrderItemModifierDto del backend.
class OrderModifierInput {
  const OrderModifierInput({
    required this.optionId,
    required this.action,
    this.replacesOptionId,
  });

  final String optionId;

  /// 'added' | 'removed' — el enum del backend.
  final String action;

  /// Solo en `added` de un reemplazo gratis (§021): apunta al
  /// ingrediente incluido agotado que esta opción reemplaza.
  final String? replacesOptionId;
}
```

## 3. `create_order_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/checkout/domain/use_cases/create_order_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/placed_order.dart';
import '../failures/checkout_failure.dart';
import '../repositories/i_checkout_repository.dart';
import 'create_order_params.dart';

/// SOLID (SRP): una acción — confirmar el pedido real (POST /orders,
/// §026/backend 015). La validación de negocio es server-side; aquí
/// solo viaja el comando ya armado por el cubit.
class CreateOrderUseCase {
  const CreateOrderUseCase(this._repo);

  final ICheckoutRepository _repo;

  Future<Either<CheckoutFailure, PlacedOrder>> call(
    CreateOrderParams params,
  ) => _repo.createOrder(params);
}
```

## 4. `placed_order_model.dart` (archivo nuevo)

**Ruta:** `lib/features/checkout/data/models/placed_order_model.dart`

```dart
import '../../domain/entities/placed_order.dart';

/// Parser del OrderResponseDto (§015). Solo toma los campos de la
/// entidad — el response trae ítems/pago/dirección completos pero el
/// checkout no los consume (el detalle real del ciclo 3 hace GET
/// /orders/:id propio).
class PlacedOrderModel extends PlacedOrder {
  const PlacedOrderModel({
    required super.id,
    required super.orderNumber,
    required super.status,
    required super.total,
  });

  factory PlacedOrderModel.fromJson(Map<String, dynamic> json) =>
      PlacedOrderModel(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as int,
        status: json['status'] as String,
        total: json['total'] as int,
      );
}
```

## 5. `checkout_failure.dart` (archivo existente — agregar al final)

**Ruta:** `lib/features/checkout/domain/failures/checkout_failure.dart`

**Después** (nuevo caso al final del archivo):

```dart
/// POST /orders rechazado por el backend (400/409 — validación o
/// regla de negocio: local cerrado, producto agotado, reemplazo
/// inválido). `message` es el texto del servidor — ya viene en
/// español producto y la UI lo muestra tal cual.
final class CheckoutOrderRejectedFailure extends CheckoutFailure {
  const CheckoutOrderRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

## 6. `i_checkout_remote_datasource.dart` (agregar método)

**Ruta:** `lib/features/checkout/data/datasources/interfaces/i_checkout_remote_datasource.dart`

```dart
  /// POST /orders — confirma el pedido (§026). Devuelve el modelo de
  /// la orden creada; errores → NetworkException cruda (los traduce
  /// el repository).
  Future<PlacedOrderModel> createOrder(Map<String, dynamic> body);
```

## 7. `checkout_remote_datasource_impl.dart` (agregar método)

**Ruta:** `lib/features/checkout/data/datasources/implementations/checkout_remote_datasource_impl.dart`

```dart
  @override
  Future<PlacedOrderModel> createOrder(Map<String, dynamic> body) async {
    final response = await _networkService.post('/orders', body: body);
    return PlacedOrderModel.fromJson(response as Map<String, dynamic>);
  }
```

## 8. `i_checkout_repository.dart` (agregar método)

**Ruta:** `lib/features/checkout/domain/repositories/i_checkout_repository.dart`

```dart
  /// POST /orders — crea el pedido real (§026/backend 015). El
  /// comando ya viene armado del cubit; 4xx de negocio llegan como
  /// CheckoutOrderRejectedFailure con el mensaje del servidor.
  Future<Either<CheckoutFailure, PlacedOrder>> createOrder(
    CreateOrderParams params,
  );
```

## 9. `checkout_repository_impl.dart` (método + mapper por llamada)

**Ruta:** `lib/features/checkout/data/repositories/checkout_repository_impl.dart`

**Antes:**

```dart
  Future<Either<CheckoutFailure, T>> _guard<T>(
    Future<T> Function() call,
  ) async {
    if (!await _networkInfo.isConnected) {
      return const Left(CheckoutOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(CheckoutServerFailure(e.toString()));
    }
  }
```

**Después:**

```dart
  @override
  Future<Either<CheckoutFailure, PlacedOrder>> createOrder(
    CreateOrderParams params,
  ) => _guard(
    () => _remoteDataSource.createOrder({
      'serviceType': params.serviceType,
      'items': [
        for (final item in params.items)
          {
            'productId': item.productId,
            'quantity': item.quantity,
            'modifiers': [
              for (final m in item.modifiers)
                {
                  'optionId': m.optionId,
                  'action': m.action,
                  if (m.replacesOptionId != null)
                    'replacesOptionId': m.replacesOptionId,
                },
            ],
          },
      ],
      'paymentMethod': params.paymentMethod,
      'clientRequestId': params.clientRequestId,
      if (params.addressId != null) 'addressId': params.addressId,
      if (params.newLandmark != null)
        'newAddress': {
          'landmark': params.newLandmark,
          if (params.newNeighborhood != null)
            'neighborhood': params.newNeighborhood,
        },
      if (params.contactPhone != null)
        'contactPhone': params.contactPhone,
      if (params.deliveryLocationLink != null)
        'deliveryLocationLink': params.deliveryLocationLink,
      if (params.payerPhone != null) 'payerPhone': params.payerPhone,
      if (params.notes != null) 'notes': params.notes,
    }),
    mapFailure: _mapOrderFailure,
  );

  /// POST /orders distingue el rechazo de negocio (4xx — el mensaje
  /// del servidor ya viene en español y se muestra) de la falla de
  /// infraestructura (5xx/timeout → genérico con retry).
  CheckoutFailure _mapOrderFailure(NetworkException e) {
    if (e is NoConnectionException) return const CheckoutOfflineFailure();
    final status = e.statusCode;
    if (status != null && status >= 400 && status < 500) {
      return CheckoutOrderRejectedFailure(e.message);
    }
    return CheckoutServerFailure(e.message);
  }

  Future<Either<CheckoutFailure, T>> _guard<T>(
    Future<T> Function() call, {
    CheckoutFailure Function(NetworkException)? mapFailure,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(CheckoutOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left((mapFailure ?? _mapFailure)(e));
    } catch (e) {
      return Left(CheckoutServerFailure(e.toString()));
    }
  }
```

## 10. `checkout_state.dart` (campo `confirmError`)

**Ruta:** `lib/features/checkout/presentation/cubit/checkout_state.dart`

```dart
    this.addressSaveFailed = false,
    this.justSavedAddress,
    this.confirmError,
  });
```

```dart
  /// POST /orders rechazado/fallido — texto resuelto por el cubit
  /// (mensaje del servidor en 4xx, l10n en offline/5xx) que la fila
  /// inline sobre el CTA muestra persistente hasta el retry. Null =
  /// sin error.
  final String? confirmError;
```

`copyWith`: `String? Function()? confirmError` (nullable-clearable, mismo patrón de `deliveryLocationLink`/`justSavedAddress`) + prop en `props`.

## 11. `checkout_cubit.dart` (confirm real)

**Ruta:** `lib/features/checkout/presentation/cubit/checkout_cubit.dart`

```dart
  CheckoutCubit({
    required this.cartCubit,
    required AuthSession authSession,
    required LoadCheckoutDataUseCase loadCheckoutDataUseCase,
    required SaveAddressUseCase saveAddressUseCase,
    required CreateOrderUseCase createOrderUseCase,
    String? clientRequestId,
  }) : _loadCheckoutData = loadCheckoutDataUseCase,
       _saveAddress = saveAddressUseCase,
       _createOrder = createOrderUseCase,
       // Idempotencia (§015): un uuid por instancia — los reintentos
       // del MISMO checkout reusan el id (doble-tap/red caída → el
       // backend devuelve la orden ya creada). Una apertura nueva del
       // checkout es una intención nueva → id nuevo.
       clientRequestId = clientRequestId ?? const Uuid().v4(),
       super(...mismo estado inicial...);
```

- Campo nuevo `final String clientRequestId;` + `final CreateOrderUseCase _createOrder;`
- **Eliminar** `final Duration confirmDelay` y su param (la llamada real reemplaza el delay).
- `_shouldSaveNewAddress`: agregar `state.justSavedAddress == null` — si el guardado ya corrió y solo falló el POST /orders, el retry NO re-guarda (y `justSavedAddress.id` va como addressId).

`confirm()` — el tramo tras la validación inline queda:

```dart
    emit(state.copyWith(confirmInProgress: true, confirmError: () => null));
    // §025 — POST /addresses ANTES de confirmar (auxiliar — si falla
    // el pedido sigue y solo se avisa con toast).
    if (_shouldSaveNewAddress) {
      ... (igual que hoy) ...
    }
    final result = await _createOrder(_buildOrderParams());
    if (isClosed) return;
    result.fold(
      // El usuario pudo salir durante el POST — emitir sobre un cubit
      // cerrado lanza StateError async.
      (failure) => emit(
        state.copyWith(
          confirmInProgress: false,
          confirmError: () => _confirmErrorText(failure),
        ),
      ),
      (_) => emit(
        state.copyWith(confirmInProgress: false, orderConfirmed: true),
      ),
    );
```

`_buildOrderParams()` — el state + el carrito → comando:

```dart
  /// Traduce el estado + el carrito al comando del §015. Destino de
  /// la entrega: `justSavedAddress` manda (ya persistida); si no, la
  /// guardada elegida; `'new'` viaja como newAddress crudo (guardada
  /// o no — si el guardado auxiliar falló, el pedido llega igual con
  /// los datos tipeados).
  CreateOrderParams _buildOrderParams() {
    final isDelivery = state.orderType == CheckoutOrderType.delivery;
    final isTransfer = state.paymentMethod == CheckoutPaymentMethod.nequi;
    final savedId =
        state.justSavedAddress?.id ??
        (state.addressId == kCheckoutNewAddressId ? null : state.addressId);
    final rawNewAddress = isDelivery && savedId == null;
    return CreateOrderParams(
      serviceType: isDelivery ? 'delivery' : 'pickup',
      paymentMethod: isTransfer ? 'transfer' : 'cash',
      clientRequestId: clientRequestId,
      addressId: isDelivery ? savedId : null,
      newLandmark: rawNewAddress ? state.newLandmark.trim() : null,
      newNeighborhood:
          rawNewAddress && state.newNeighborhood.trim().isNotEmpty
          ? state.newNeighborhood.trim()
          : null,
      contactPhone: isDelivery ? state.contactPhone.trim() : null,
      deliveryLocationLink:
          isDelivery ? state.deliveryLocationLink : null,
      payerPhone: isTransfer ? state.nequiPhone.trim() : null,
      notes: state.note.trim().isEmpty ? null : state.note.trim(),
      items: [
        for (final item in cartCubit.state.items)
          OrderItemInput(
            productId: item.productId,
            quantity: item.quantity,
            modifiers: [
              for (final m in item.modifiers)
                OrderModifierInput(
                  optionId: m.optionId,
                  action: m.action.name,
                  replacesOptionId: m.replacesOptionId,
                ),
            ],
          ),
      ],
    );
  }

  /// Texto de la fila de error: el motivo del servidor en 4xx
  /// (español producto), l10n propio en offline/inesperado.
  String _confirmErrorText(CheckoutFailure failure) {
    final l10n = AppLocalizationsEs();
    return switch (failure) {
      CheckoutOrderRejectedFailure(:final message) => message,
      CheckoutOfflineFailure() => l10n.checkoutOrderOffline,
      _ => l10n.checkoutOrderFailed,
    };
  }
```

`deliveryLocationLink` **sí viaja** cuando está adjunto (aunque hoy sea el link mock — el pipe queda probado para la geo real, decisión #1). `items[].notes` no (el carrito no tiene nota por ítem).

## 12. `checkout_screen.dart` (fila de error sobre el CTA)

**Ruta:** `lib/features/checkout/presentation/screens/checkout_screen.dart`

En el `Column` del footer, inmediatamente antes del `FilledButton` de confirmar:

```dart
          // §026 — error persistente del POST /orders (misma familia
          // de avisos inline del §025): el motivo real del servidor
          // o el l10n genérico; se limpia al reintentar.
          if (state.confirmError != null) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: colors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    state.confirmError!,
                    style: text.bodySmall?.copyWith(color: colors.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
```

El CTA queda habilitado de nuevo (confirmInProgress:false) → reintentar con el mismo `clientRequestId`.

## 13. `setup_di.dart`

**Ruta:** `lib/core/di/setup_di.dart`

```dart
  locator.registerLazySingleton<CreateOrderUseCase>(
    () => CreateOrderUseCase(locator<ICheckoutRepository>()),
  );
```

y en el factory del `CheckoutCubit`: `createOrderUseCase: locator<CreateOrderUseCase>(),` (+ imports).

## 14. `app_es.arb` (2 keys nuevas → `flutter gen-l10n`)

```json
  "checkoutOrderFailed": "No pudimos confirmar tu pedido — inténtalo de nuevo",
  "@checkoutOrderFailed": {
    "description": "Error genérico inline del POST /orders (5xx/inesperado)"
  },
  "checkoutOrderOffline": "Sin internet — revisa tu conexión e inténtalo de nuevo",
  "@checkoutOrderOffline": {
    "description": "Error inline del POST /orders sin conectividad"
  },
```

## 15. `pubspec.yaml`

`flutter pub add uuid` (clientRequestId v4 por instancia de checkout).

## 16-18. Tests

- **`create_order_use_case_test.dart`** — passthrough + propagación del Either.
- **`checkout_repository_impl_test.dart`** — createOrder: éxito parsea · offline → `CheckoutOfflineFailure` · 409 con `message` del server → `CheckoutOrderRejectedFailure(msg)` · 500 → `CheckoutServerFailure` · wire map respeta el contrato (XOR addressId/newAddress, replacesOptionId solo presente cuando aplica).
- **`checkout_cubit_test.dart`** — el confirm actual (delay mock) se reescribe: éxito → `orderConfirmed` con el payload exacto por combinación (pickup+nequi → transfer+payerPhone, sin contactPhone; delivery+cash → cash+contactPhone, sin payerPhone; delivery+nequi → ambos phones; `justSavedAddress.id` como addressId; `'new'` sin guardar → `newAddress`); fallo → `confirmError` con el motivo + `confirmInProgress:false`; retry tras fallo → mismo `clientRequestId` y `saveAddress` NO se re-llama cuando `justSavedAddress` ya existe.
- **`checkout_screen_test.dart`** — fila de error visible con el motivo + CTA re-habilitado; el diálogo de éxito no cambia.

---

## Orden de aplicación

1. `pubspec.yaml` (`uuid`) + `app_es.arb` + `flutter gen-l10n`
2. `placed_order.dart` + `create_order_params.dart` + `checkout_failure.dart` (dominio)
3. `create_order_use_case.dart` + `i_checkout_repository.dart` (contratos)
4. `placed_order_model.dart` + `i_checkout_remote_datasource.dart` + `checkout_remote_datasource_impl.dart` + `checkout_repository_impl.dart` (data)
5. `checkout_state.dart` + `checkout_cubit.dart` (presentación)
6. `checkout_screen.dart` (fila de error)
7. `setup_di.dart` (wiring)
8. Tests nuevos/actualizados
9. `flutter analyze` + `flutter test`
