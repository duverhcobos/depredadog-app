# Propuesta: Pedidos reales — tab + detalle + cancelar (GET/POST /orders)

Ciclo 3 de integración (ver `026-checkout-post-orders.md`). El tab Pedidos y su detalle dejan los mocks: `GET /orders?bucket=active` + `GET /orders?bucket=history&page=N` + `GET /orders/:id` + `POST /orders/:id/cancel` (backend §015). Con esto el flujo del cliente queda 100% real de punta a punta.

**Contrato** (`documentacion/api/orders/00{2,3,4}-*.md`):
- `GET /orders?bucket=active` — en curso sin paginar; `bucket=history&page=&limit=` — terminados paginados. Envelope común `{items,total,page,limit}`; **`items[].modifiers` viaja `[]` en el listado** (la card solo necesita ítems+chip de pago).
- `GET /orders/:id` — detalle completo **con modifiers** (única fuente del panel por secciones); 404 también para ajeno.
- `POST /orders/:id/cancel` — solo `pending`; orden cancelled + payment failed en la misma tx. Body `{reason?}`.

**Decisiones encuestadas** (registro al pie).

---

## Mapeo response → `CustomerOrder`

| Campo app | Origen | Nota |
|---|---|---|
| `status` | `pending→received`, `confirmed`, `preparing`, `done`, `cancelled` | el enum app llama "received" al pending del backend |
| `paymentMethod` | `transfer→nequi`, `cash→onDelivery` | |
| `paymentStatus` | `pending/paid/failed` — `payment:null` → pending | defensivo (pedidos viejos sin fila) |
| `placedAt` | `createdAt` (ISO → DateTime) | |
| `statusChangedAt` | — `null` (el response no lo trae) | |
| `landmark` | `deliveryAddress` completo ("ref (barrio)") | snapshot único — `addressLabel`/`neighborhood` quedan null |
| `hasLocationPin` | `deliveryLocationLink != null` | |
| `productSlug` | `productSlug` directo (§016) — `null` legacy → `''` → fallback de marca | |
| `storeReference` | `null` → el detalle muestra el l10n genérico | el response no lo trae |
| `contactPhone`,`note`,`cancelReason`,`subtotal`,`deliveryFee` | directos | `note`←`notes` |
| `items[].includedNames` | `includedNames` directo (§016) — `[]` legacy → sin sección "Lleva:" | |
| `modifiers` | `action`,`optionId`,`optionName`,`priceDelta`,`modifierGroup` (slug §016),`replacesOptionId` (§016) | mapeo slug→enum abajo |

**Mapeo `modifierGroup` (slug backend) → `CartModifierGroup`** (misma asignación que `product_detail_screen`):

| Condición | Enum app |
|---|---|
| `action: removed` | `ingredient` (convención: quitados siempre ingrediente) |
| `added` + `replacesOptionId != null` | `ingredient` (la fila del reemplazo también es ingrediente) |
| `added` + slug `toppings` | `topping` |
| `added` + slug `sauces` | `sauce` |
| `added` + slug `ingredients` / `null` legacy | `extra` (fallback ya documentado en el enum) |

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/orders/domain/failures/orders_failure.dart` | **nuevo** — sealed offline/server/rejected |
| `lib/features/orders/domain/repositories/i_orders_repository.dart` | **nuevo** — getActive/getHistory/getOrder/cancel |
| `lib/features/orders/domain/use_cases/{load_orders,load_more_history,get_order_detail,cancel_order}_use_case.dart` | **4 nuevos** |
| `lib/features/orders/data/datasources/{interfaces,implementations}/orders_remote_datasource*.dart` | **nuevo** |
| `lib/features/orders/data/models/customer_order_model.dart` | **nuevo** — parser + mapeos de enums |
| `lib/features/orders/data/repositories/orders_repository_impl.dart` | **nuevo** — `_guard` traductor (familia checkout) |
| `lib/features/orders/presentation/cubit/orders_state.dart` | + flags loading/failed/hasMore/cancelling |
| `lib/features/orders/presentation/cubit/orders_cubit.dart` | mocks mueren → `loadOrders`/`loadMoreHistory`/`refreshOrder`/`cancelOrder` reales |
| `lib/features/orders/presentation/screens/orders_screen.dart` | loading inicial + error/retry por sección + "Cargar más" + refresh real |
| `lib/features/orders/presentation/screens/order_detail_screen.dart` | resuelve por id del cubit (fresco) + cancel async |
| `lib/features/orders/presentation/widgets/active_order_card.dart` | cancel async + toast error |
| `lib/core/routes/app_router.dart` | `..loadOrders()` en el tab + `..refreshOrder(id)` en el detalle |
| `lib/core/di/setup_di.dart` | datasource/repo/use-cases + deps del cubit |
| `lib/l10n/app_es.arb` | + keys de carga/error/paginación/cancel → `flutter gen-l10n` |
| tests | cubit reescrito con use-cases mockeados + repo/use-cases nuevos + screen |

## 1. `orders_failure.dart` (nuevo)

**Ruta:** `lib/features/orders/domain/failures/orders_failure.dart`

```dart
import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de Pedidos — el
/// repository impl traduce NetworkException; la UI elige el mensaje
/// (misma convención de CheckoutFailure/CatalogFailure).
sealed class OrdersFailure extends Equatable {
  const OrdersFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad.
final class OrdersOfflineFailure extends OrdersFailure {
  const OrdersOfflineFailure();
}

/// 4xx/5xx o inesperado — `message` se conserva para logging; la UI
/// muestra su propio texto salvo en el rechazo de cancelar.
final class OrdersServerFailure extends OrdersFailure {
  const OrdersServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// POST /orders/:id/cancel rechazado (409 — ya no está pending; el
/// mensaje del servidor viene en español y se muestra tal cual).
final class OrdersCancelRejectedFailure extends OrdersFailure {
  const OrdersCancelRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

## 2. `i_orders_repository.dart` (nuevo)

**Ruta:** `lib/features/orders/domain/repositories/i_orders_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';

/// SOLID (DIP): contrato de Pedidos — la presentación no conoce HTTP.
abstract class IOrdersRepository {
  /// GET /orders?bucket=active — en curso, sin paginar.
  Future<Either<OrdersFailure, List<CustomerOrder>>> getActiveOrders();

  /// GET /orders?bucket=history&page=N — terminados paginados;
  /// devuelve items + total del bucket para el "Cargar más".
  Future<Either<OrdersFailure, OrdersHistoryPage>> getHistoryOrders(
    int page,
  );

  /// GET /orders/:id — detalle completo CON modifiers (única fuente
  /// del panel por secciones — el listado los omite, §015).
  Future<Either<OrdersFailure, CustomerOrder>> getOrderDetail(String id);

  /// POST /orders/:id/cancel — solo pending; 409 llega como
  /// OrdersCancelRejectedFailure con el mensaje del servidor.
  Future<Either<OrdersFailure, CustomerOrder>> cancelOrder(
    String id,
    String reason,
  );
}

/// Página del historial — la entidad lista vive en domain/entities
/// pero el conteo del bucket es dato de paginación propio del repo.
class OrdersHistoryPage {
  const OrdersHistoryPage({required this.items, required this.total});

  final List<CustomerOrder> items;
  final int total;
}
```

## 3. Use-cases (4 archivos nuevos)

**Ruta:** `lib/features/orders/domain/use_cases/load_orders_use_case.dart`

Fan-out idéntico a `LoadCheckoutDataUseCase` — active+history en paralelo, cada pierna su Either (una falla no tumba la otra):

```dart
import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';
import '../repositories/i_orders_repository.dart';

/// Resultado de la carga del tab — cada pierna degrada por separado
/// (activos puede llegar aunque el historial falle, y viceversa).
class OrdersDataResult {
  const OrdersDataResult({required this.active, required this.history});

  final Either<OrdersFailure, List<CustomerOrder>> active;
  final Either<OrdersFailure, OrdersHistoryPage> history;
}

/// SOLID (SRP): carga inicial / pull-to-refresh / reload al entrar
/// al tab — activos + primera página del historial en paralelo.
class LoadOrdersUseCase {
  const LoadOrdersUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<OrdersDataResult> call() async {
    final results = await Future.wait([
      _repo.getActiveOrders(),
      _repo.getHistoryOrders(1),
    ]);
    return OrdersDataResult(
      active: results[0] as Either<OrdersFailure, List<CustomerOrder>>,
      history: results[1] as Either<OrdersFailure, OrdersHistoryPage>,
    );
  }
}
```

**Ruta:** `lib/features/orders/domain/use_cases/load_more_history_use_case.dart`

```dart
/// SOLID (SRP): una acción — la página siguiente del historial
/// ("Cargar más" — GET /orders?bucket=history&page=N).
class LoadMoreHistoryUseCase {
  const LoadMoreHistoryUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, OrdersHistoryPage>> call(int page) =>
      _repo.getHistoryOrders(page);
}
```

**Ruta:** `lib/features/orders/domain/use_cases/get_order_detail_use_case.dart`

```dart
/// SOLID (SRP): refrescar UN pedido al abrir su detalle — el listado
/// omite modifiers a propósito (§015): solo :id los trae, junto al
/// estado más fresco (el stepper cambia server-side).
class GetOrderDetailUseCase {
  const GetOrderDetailUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, CustomerOrder>> call(String id) =>
      _repo.getOrderDetail(id);
}
```

**Ruta:** `lib/features/orders/domain/use_cases/cancel_order_use_case.dart`

```dart
/// SOLID (SRP): cancelar el pedido propio (POST /orders/:id/cancel,
/// solo pending — §015). La razón fija del cliente la pone el cubit
/// (el diálogo aprobado no tiene campo de texto — §023).
class CancelOrderUseCase {
  const CancelOrderUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, CustomerOrder>> call(
    String id,
    String reason,
  ) => _repo.cancelOrder(id, reason);
}
```

## 4. `i_orders_remote_datasource.dart` + impl (nuevos)

**Ruta:** `lib/features/orders/data/datasources/interfaces/i_orders_remote_datasource.dart`

```dart
import '../../models/customer_order_model.dart';

/// Contrato del datasource remoto de Pedidos — endpoints §015;
/// devuelve models/maps crudos, errores como NetworkException.
abstract class IOrdersRemoteDataSource {
  /// GET /orders?bucket — activos sin `page`; historial con `page`
  /// (el envelope devuelve items + total para el "Cargar más").
  Future<({List<CustomerOrderModel> items, int total})> fetchOrdersPage(
    String bucket, {
    int? page,
  });
  Future<CustomerOrderModel> fetchOrderDetail(String id);
  Future<CustomerOrderModel> cancelOrder(String id, String reason);
}
```

**Ruta:** `lib/features/orders/data/datasources/implementations/orders_remote_datasource_impl.dart`

```dart
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/customer_order_model.dart';
import '../interfaces/i_orders_remote_datasource.dart';

/// SOLID (SRP): solo llama los endpoints y parsea — el Bearer lo pone
/// el AuthInterceptor, los errores los traduce el repository.
class OrdersRemoteDataSourceImpl implements IOrdersRemoteDataSource {
  const OrdersRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  /// El envelope {items,total,page,limit} — items + total para el
  /// "Cargar más"; `page` null (bucket active) no pagina.
  @override
  Future<({List<CustomerOrderModel> items, int total})> fetchOrdersPage(
    String bucket, {
    int? page,
  }) async {
    final response = await _networkService.get(
      '/orders',
      queryParameters: {
        'bucket': bucket,
        if (page != null) 'page': page,
      },
    );
    final envelope = response as Map<String, dynamic>;
    return (
      items: (envelope['items'] as List<dynamic>)
          .map((o) => CustomerOrderModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      total: envelope['total'] as int,
    );
  }

  @override
  Future<CustomerOrderModel> fetchOrderDetail(String id) async {
    final response = await _networkService.get('/orders/$id');
    return CustomerOrderModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<CustomerOrderModel> cancelOrder(String id, String reason) async {
    final response = await _networkService.post(
      '/orders/$id/cancel',
      body: {'reason': reason},
    );
    return CustomerOrderModel.fromJson(response as Map<String, dynamic>);
  }
}
```

## 5. `customer_order_model.dart` (nuevo)

**Ruta:** `lib/features/orders/data/models/customer_order_model.dart`

Parser del `OrderResponseDto` con los mapeos de la tabla de arriba:

```dart
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../domain/entities/customer_order.dart';

/// Parser del OrderResponseDto (§015/016) → CustomerOrder. Los
/// mapeos: status pending→received · transfer→nequi · cash→onDelivery
/// · payment null→pending defensivo · deliveryAddress→landmark ·
/// modifierGroup slug→enum con las mismas reglas del detalle del
/// producto · NULL legacy → degradación documentada.
class CustomerOrderModel extends CustomerOrder {
  const CustomerOrderModel({
    required super.id,
    required super.serviceType,
    required super.status,
    required super.items,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.subtotal,
    required super.deliveryFee,
    required super.placedAt,
    super.landmark,
    super.hasLocationPin,
    super.contactPhone,
    super.note,
    super.cancelReason,
  }) : super(addressLabel: null, neighborhood: null, storeReference: null);

  factory CustomerOrderModel.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    return CustomerOrderModel(
      id: json['id'] as String,
      serviceType: json['serviceType'] == 'delivery'
          ? OrderServiceType.delivery
          : OrderServiceType.pickup,
      status: switch (json['status'] as String) {
        'pending' => OrderStatus.received,
        'confirmed' => OrderStatus.confirmed,
        'preparing' => OrderStatus.preparing,
        'done' => OrderStatus.done,
        _ => OrderStatus.cancelled,
      },
      items: [
        for (final i in json['items'] as List<dynamic>)
          OrderItem(
            productId: (i as Map<String, dynamic>)['productId'] as String,
            // §016 — null en filas viejas → '' → fallback de marca.
            productSlug: i['productSlug'] as String? ?? '',
            name: i['productName'] as String,
            quantity: i['quantity'] as int,
            unitPrice: i['unitPrice'] as int,
            includedNames: [
              for (final n in (i['includedNames'] as List<dynamic>? ?? []))
                n as String,
            ],
            modifiers: [
              for (final m in i['modifiers'] as List<dynamic>)
                _modifierFromJson(m as Map<String, dynamic>),
            ],
          ),
      ],
      paymentMethod: payment?['method'] == 'cash'
          ? OrderPaymentMethod.onDelivery
          : OrderPaymentMethod.nequi,
      paymentStatus: switch (payment?['status'] as String?) {
        'paid' => OrderPaymentStatus.paid,
        'failed' => OrderPaymentStatus.failed,
        _ => OrderPaymentStatus.pending,
      },
      subtotal: json['subtotal'] as int,
      deliveryFee: json['deliveryFee'] as int,
      placedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      landmark: json['deliveryAddress'] as String?,
      hasLocationPin: json['deliveryLocationLink'] != null,
      contactPhone: json['contactPhone'] as String?,
      note: json['notes'] as String?,
      cancelReason: json['cancelReason'] as String?,
    );
  }

  /// Fila de modifier — el group sale del slug del snapshot §016 con
  /// la misma asignación del detalle del producto: removed y la fila
  /// del reemplazo siempre `ingredient`; added por slug; null legacy
  /// → `extra` (fallback documentado del enum).
  static CartModifier _modifierFromJson(Map<String, dynamic> m) {
    final action = m['action'] == 'added'
        ? CartModifierAction.added
        : CartModifierAction.removed;
    final replaces = m['replacesOptionId'] as String?;
    final groupSlug = m['modifierGroup'] as String?;
    final group = action == CartModifierAction.removed || replaces != null
        ? CartModifierGroup.ingredient
        : switch (groupSlug) {
            'toppings' => CartModifierGroup.topping,
            'sauces' => CartModifierGroup.sauce,
            _ => CartModifierGroup.extra,
          };
    return CartModifier(
      optionId: m['optionId'] as String? ?? '',
      optionName: m['optionName'] as String,
      action: action,
      priceDelta: m['priceDelta'] as int,
      replacesOptionId: replaces,
      group: group,
    );
  }
}
```

## 6. `orders_repository_impl.dart` (nuevo)

**Ruta:** `lib/features/orders/data/repositories/orders_repository_impl.dart`

Mismo `_guard` traductor que el checkout; el cancel tiene mapper propio (409 → `OrdersCancelRejectedFailure` con el mensaje):

```dart
class OrdersRepositoryImpl implements IOrdersRepository {
  const OrdersRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final IOrdersRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<OrdersFailure, List<CustomerOrder>>> getActiveOrders() =>
      _guard(() async =>
          (await _remoteDataSource.fetchOrdersPage('active')).items);

  @override
  Future<Either<OrdersFailure, OrdersHistoryPage>> getHistoryOrders(
    int page,
  ) => _guard(() async {
    final res = await _remoteDataSource.fetchOrdersPage(
      'history',
      page: page,
    );
    return OrdersHistoryPage(items: res.items, total: res.total);
  });

  @override
  Future<Either<OrdersFailure, CustomerOrder>> getOrderDetail(String id) =>
      _guard(() => _remoteDataSource.fetchOrderDetail(id));

  @override
  Future<Either<OrdersFailure, CustomerOrder>> cancelOrder(
    String id,
    String reason,
  ) => _guard(
    () => _remoteDataSource.cancelOrder(id, reason),
    mapFailure: (e) {
      if (e is NoConnectionException) return const OrdersOfflineFailure();
      if (e is ServerException && e.statusCode == 409) {
        return OrdersCancelRejectedFailure(e.message);
      }
      return OrdersServerFailure(e.message);
    },
  );

  Future<Either<OrdersFailure, T>> _guard<T>(
    Future<T> Function() call, {
    OrdersFailure Function(NetworkException)? mapFailure,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(OrdersOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left((mapFailure ?? _mapFailure)(e));
    } catch (e) {
      return Left(OrdersServerFailure(e.toString()));
    }
  }

  OrdersFailure _mapFailure(NetworkException e) =>
      e is NoConnectionException
          ? const OrdersOfflineFailure()
          : OrdersServerFailure(e.message);
}
```

## 7. `orders_state.dart` (flags nuevos)

```dart
  const OrdersState({
    this.active = const [],
    this.history = const [],
    this.dataLoading = true,
    this.activeFailed = false,
    this.historyFailed = false,
    this.historyTotal = 0,
    this.historyLoadingMore = false,
    this.historyLoadMoreFailed = false,
  });
```

- `historyHasMore` getter: `history.length < historyTotal`.
- copyWith + props para los campos nuevos.

## 8. `orders_cubit.dart` (reescritura)

Los `kMockOrder*`/`kMockHistory` mueren. Ctor con use-cases (sin seeds — los tests mockean):

```dart
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required LoadOrdersUseCase loadOrdersUseCase,
    required LoadMoreHistoryUseCase loadMoreHistoryUseCase,
    required GetOrderDetailUseCase getOrderDetailUseCase,
    required CancelOrderUseCase cancelOrderUseCase,
  }) : _loadOrders = ..., super(const OrdersState());
```

- **`loadOrders()`** — `dataLoading:true`, flags a false → `await _loadOrders()` → cada pierna fold (active falla → `activeFailed:true` + lista vacía; history falla → `historyFailed:true` + `historyTotal:0`). Reentrante seguro (no early-return; es refresh también — guardar solo `if (state.historyLoadingMore)`? no — loadOrders es carga completa; un loading paralelo no compite. Guardar contra reentry con un bool interno `_loading` simple).
- **`loadMoreHistory()`** — guarda `historyHasMore && !historyLoadingMore && !historyLoadMoreFailed`? no — el retry debe poder reintentar: guarda `!historyLoadingMore`; page = `history.length ~/ 20 + 1` → fold: éxito → `history: [...history, ...items]` + `historyTotal` + `historyLoadingMore:false`; falla → `historyLoadMoreFailed:true` (la fila "Cargar más" muestra error+retry).
- **`refreshOrder(id)`** — `_getOrderDetail(id)` → éxito: reemplaza la entidad donde esté (active o history — la cancelada por el admin puede haber cambiado de bucket: si status terminal → quita de active, inserta al frente de history). Falla: silenciosa — el detalle queda con el snapshot del listado (la resincronización la da el pull-to-refresh del tab).
- **`cancelOrder(id)` → `Future<String?>`** — devuelve `null` éxito / texto de error. Éxito: el response `CustomerOrder` migra a history al frente + quita de active. Falla: devuelve el mensaje (server en 409, l10n genérico en otro caso) y además dispara `loadOrders()` silencioso para resincronizar (el 409 dice que ya cambió server-side).

## 9. `orders_screen.dart`

- `BlocBuilder` nuevo árbol: `dataLoading` inicial → `Center(CircularProgressIndicator(color: primary))` tras el título.
- `activeFailed` → fila inline de error+retry (familia §025) donde irían las cards activas; `historyFailed` → idéntica bajo el heading Historial.
- Fin del historial: `historyHasMore` → botón "Cargar más" (o fila de error+retry si `historyLoadMoreFailed`); `historyLoadingMore` → mini-spinner.
- `onRefresh` → `await context.read<OrdersCubit>().loadOrders()` real.
- Vacío solo cuando `!dataLoading && isEmpty && !activeFailed && !historyFailed`.

## 10. `order_detail_screen.dart`

- El screen resuelve el pedido por id desde el cubit: `BlocBuilder<OrdersCubit, OrdersState>` → `state.active/history` firstWhereOrNull(id) ?? `widget.order` (snapshot instantáneo). Así `refreshOrder` actualiza estado+modifiers en vivo, y la ventana de cancelar desaparece sola si el admin confirmó.
- `_confirmCancel`: `final error = await cubit.cancelOrder(order.id)` → `null` → toast `orderCancelledToast` + pop; texto → `AppToast.info(context, error)` y NO pop (el pedido se ve con su estado real tras el resync).

## 11. `active_order_card.dart`

El cancel del card hace el mismo await del cubit (revisar su flujo actual — probablemente llama `cancelOrder` sync + toast de éxito ya) → await + toast éxito / toast error según el retorno.

## 12. `app_router.dart`

- Tab: `value: locator<OrdersCubit>()..loadOrders()` — cada visita al tab recarga (el estado del pedido cambia server-side — el cliente entra a revisar si avanzó).
- Detalle: `value: locator<OrdersCubit>()..refreshOrder((state.extra! as CustomerOrder).id)` — al abrir un detalle se trae el estado fresco + modifiers completos.

## 13. `setup_di.dart`

```dart
  locator.registerLazySingleton<IOrdersRemoteDataSource>(...);
  locator.registerLazySingleton<IOrdersRepository>(() => OrdersRepositoryImpl(
      remoteDataSource: ..., networkInfo: ...));
  locator.registerLazySingleton<LoadOrdersUseCase>(...);
  locator.registerLazySingleton<LoadMoreHistoryUseCase>(...);
  locator.registerLazySingleton<GetOrderDetailUseCase>(...);
  locator.registerLazySingleton<CancelOrderUseCase>(...);
  locator.registerLazySingleton<OrdersCubit>(() => OrdersCubit(
      loadOrdersUseCase: ..., loadMoreHistoryUseCase: ...,
      getOrderDetailUseCase: ..., cancelOrderUseCase: ...));
```

## 14. `app_es.arb` (keys nuevas → `flutter gen-l10n`)

```json
"ordersLoadError": "No pudimos cargar tus pedidos",
"ordersRetry": "Reintentar",
"ordersLoadMore": "Cargar más",
"ordersLoadMoreError": "No pudimos cargar más pedidos",
"ordersCancelError": "No pudimos cancelar el pedido — inténtalo de nuevo",
```

(el mensaje del 409 del servidor se muestra tal cual — ya viene en español; el genérico solo para offline/5xx.)

## 15. Tests

- `orders_cubit_test.dart` — reescrito: carga OK/degradación por pierna, loadMore acumulación+tope+falla, refreshOrder reemplaza+migra de bucket, cancelOrder éxito (migra+retorna null) / 409 (texto del server + resync).
- `orders_repository_impl_test.dart` — envelope→OrdersHistoryPage, mapeos de enums (pending→received, transfer→nequi), payment null→pending, cancel 409→CancelRejected.
- `customer_order_model_test.dart` — parser completo (defensivos incluidos).
- `orders_screen_test.dart` — loading, error+retry por sección, Cargar más, vacío, refresh real.
- use-cases — passthrough.

## Mocks que mueren

`kMockOrderDelivery`, `kMockOrderPickup`, `kMockOrderDeliveryCash`, `kMockHistory` y los params `seedActive`/`seedHistory` del cubit — todo el tab queda real.

---

## Orden de aplicación

1. Failure + repo interface + entidad auxiliar + model + datasource + repo impl
2. Use-cases + state + cubit
3. Screen + detalle + card + router + DI + l10n
4. Tests
5. `flutter analyze` + `flutter test` → emulador (la orden #1 real debe verse) → aprobación → commit

---

## Encuesta de revisión (cerrada — aprobado)

| Decisión | Resultado |
|---|---|
| Foto del ítem sin slug en el response | **Resuelto por el usuario**: "el backend se adapta al diseño" → §016 backend entrega `productSlug` real (commiteado `83cbf49`); `null` legacy → fallback de marca |
| Secciones del detalle sin grupo/reemplazo/incluidos | **Resuelto por §016**: `modifierGroup`/`replacesOptionId`/`includedNames` viajan reales → el detalle reproduce el carrito idéntico; `null` legacy degrada al fallback documentado del enum |
| Paginación del historial | **Botón "Cargar más"** (default del agente, encuesta omitida): explícito, testeable, el fallo muestra retry en la misma fila |
| Frescura del estado | **Recargar en cada visita al tab** (default del agente, encuesta omitida): `..loadOrders()` en el pageBuilder + pull-to-refresh — el cliente entra a ver si el pedido avanzó |

---

## Anexo post-implementación

**Auditoría `revisor`:** 1 CRÍTICO + 3 IMPORTANTE + MENORes, todos corregidos:

- **CRÍTICO** — los mensajes de `DomainException` del backend llegan en inglés ("Order can only be cancelled while pending"): el 409 de cancel NO puede mostrar el texto del servidor → `ordersCancelRejected` dedicado ("Este pedido ya no se puede cancelar — el local ya lo tomó"). Mismo bug latente corregido en checkout §026: la fila de rechazo del POST /orders ya no muestra el mensaje crudo → `checkoutOrderRejected` genérico dedicado.
- **IMPORTANTE** — `limit` del historial viajaba sin valor explícito → `kOrdersHistoryPageSize` compartido (contrato repo/datasource).
- **IMPORTANTE** — el reload por visita al tab solo disparaba con tap en el nav bar → `onDestinationSelected` del shell + guard `isRegistered`.
- **IMPORTANTE** — status desconocido mapeaba a `cancelled` (un status nuevo del backend pintaba "Cancelado" en un pedido vivo) → fallback a `received` + `cancelled` explícito.
- **MENORes** — modelo defensivo en `productSlug`/`includedNames`/`modifierGroup`/`replacesOptionId` (null → fallback), `OrdersCubit` separa cargas/fallos por pierna, copy de "Cargar más" a l10n.

**Hallazgo en vivo (emulador):** el `go('/orders')` programático del diálogo de éxito del checkout no pasaba por `onDestinationSelected` → aterrizabas en Pedidos sin la orden recién creada. Corregido: el handler del CTA dispara `locator<OrdersCubit>().loadOrders()` antes de navegar — verificado en vivo con la orden #3 (apareció sola al aterrizar).

**Verificación en vivo:** `GET /orders?bucket=active` (órdenes #3+#1 reales con foto `product_slug`), `bucket=history&page&limit=20` (cancelada en historial), `GET /orders/:id` con fidelidad §016 completa ("Ingredientes" `included_names` + "Se le quitó" + "Adicionales"), `POST /orders/:id/cancel` real (migración + toast + `cancel_reason` en BD), pull-to-refresh, degradación honesta de la orden legacy #1. **447/447 tests, analyze limpio.** Aprobado visualmente por el usuario.
