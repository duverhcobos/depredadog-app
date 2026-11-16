# Propuesta 038: Integración `GET /admin/orders` — la cola de Cocina sale de mocks

Primera integración del tab Cocina (fase 2 de §036/§037 — un endpoint a la
vez). `load()` del `AdminQueueCubit` deja los mocks y consume
`GET /admin/orders` (backend 019+022, ya committeado en `6fe55ec`): bucket
`active` alimenta los 5 carriles y bucket `history` (página 1) alimenta el
historial provisional.

Las **operaciones** (`advanceOrder`, `markPaid`, `cancelOrder`,
`loadDayClosePreview`, `closeDay`) siguen siendo mutaciones LOCALES sobre el
estado — quedan marcadas `// PROVISIONAL` y se conectan en sus propios ciclos
(PATCH status, confirm-payment, day-close).

Patrón espejo del feature `orders` del cliente (§027): datasource →
repository `Either` → use case → cubit. No hay visual nuevo — la pantalla
aprobada define el contrato.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/data/models/admin_order_model.dart` | **nuevo** — parser `AdminOrderResponseDto` → `AdminOrder` |
| `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart` | **nuevo** — puerto remoto |
| `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart` | **nuevo** — `GET /admin/orders` |
| `lib/features/admin/domain/failures/admin_failure.dart` | **nuevo** — failures de dominio |
| `lib/features/admin/domain/repositories/i_admin_repository.dart` | **nuevo** — puerto + `AdminHistoryPage` |
| `lib/features/admin/data/repositories/admin_repository_impl.dart` | **nuevo** — `_guard` offline/NetworkException |
| `lib/features/admin/domain/use_cases/load_admin_queue_use_case.dart` | **nuevo** — active + history en paralelo |
| `lib/features/orders/data/models/order_item_modifier_mapper.dart` | **nuevo** — parser de modifiers compartido (extraído) |
| `lib/features/orders/data/models/customer_order_model.dart` | actualización — delega en el mapper compartido |
| `lib/features/admin/domain/entities/admin_order.dart` | actualización — `orderNumber` + getter `shortTag` |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | actualización — inyecta use case; `load()` real; mocks salen a fixtures; mutaciones PROVISIONAL |
| `lib/features/admin/presentation/widgets/order_detail/admin_order_detail_header.dart` | actualización — usa `order.shortTag` |
| `lib/core/di/setup_di.dart` | actualización — registros admin |
| `test/features/admin/fixtures/admin_order_fixtures.dart` | **nuevo** — los mocks movidos verbatim |
| `test/features/admin/data/models/admin_order_model_test.dart` | **nuevo** |
| `test/features/admin/data/repositories/admin_repository_impl_test.dart` | **nuevo** |
| `test/features/admin/domain/use_cases/load_admin_queue_use_case_test.dart` | **nuevo** |
| `test/features/admin/presentation/cubit/admin_queue_cubit_test.dart` | actualización — mock del use case |
| `test/features/admin/presentation/screens/{admin_queue_screen,admin_order_detail_screen,admin_day_close_screen,admin_history_screen}_test.dart` | actualización — cubit con use case falso |

---

## 1. `admin_order_model.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/data/models/admin_order_model.dart`

```dart
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../../orders/data/models/order_item_modifier_mapper.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';

/// Parser del AdminOrderResponseDto (backend §019 + §022/§037) → AdminOrder.
/// Misma convención de CustomerOrderModel — mapeos:
/// · status 'pending'→received; un status desconocido NUNCA cae a terminal
///   (fallback received, revisor §027).
/// · serviceType 'dine_in'→dineIn (solo existe en pedidos del local).
/// · channel 'presencial'→presencial (lo tomó el dueño); else online.
/// · payment NULL (pedidos viejos sin fila de pago) → cash + pending
///   defensivo — la puerta de pago de Cocina lo trata como "sin cobrar".
/// · Dirección desglosada (§037.B): deliveryAddressLabel/Landmark/
///   Neighborhood; cuando no hay ficha de dirección (pedidos por teléfono
///   sin addressId) el landmark cae al snapshot crudo `deliveryAddress`
///   ("punto de referencia (barrio)") — mismo fallback del DTO.
/// · deliveryLocationLink → locationUrl: el pin canónico (§037) — la app
///   NUNCA reconstruye el link cuando el backend lo trae; hasLocationPin
///   = link != null (lat/lng no viajan en el DTO admin).
/// · statusChangedAt → el reloj de la cola por carril (§037.A).
class AdminOrderModel extends AdminOrder {
  const AdminOrderModel({
    required super.id,
    super.orderNumber,
    required super.channel,
    required super.serviceType,
    required super.status,
    required super.items,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.subtotal,
    required super.deliveryFee,
    required super.placedAt,
    super.statusChangedAt,
    super.tableLabel,
    super.customerName,
    super.cancelReason,
    super.addressLabel,
    super.landmark,
    super.neighborhood,
    super.hasLocationPin,
    super.contactPhone,
    super.note,
    super.locationUrl,
  });

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    final link = json['deliveryLocationLink'] as String?;
    // Fallback §037.B: sin ficha de dirección, el snapshot crudo hace
    // de landmark ("Casa blanca frente a la cancha (Barrio Centro)").
    final landmark =
        json['deliveryLandmark'] as String? ?? json['deliveryAddress'] as String?;
    final statusChangedAt = json['statusChangedAt'] as String?;
    return AdminOrderModel(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as int?,
      channel: json['channel'] == 'presencial'
          ? AdminOrderChannel.presencial
          : AdminOrderChannel.online,
      serviceType: switch (json['serviceType'] as String) {
        'delivery' => AdminServiceType.delivery,
        'dine_in' => AdminServiceType.dineIn,
        _ => AdminServiceType.pickup,
      },
      status: switch (json['status'] as String) {
        'pending' => OrderStatus.received,
        'confirmed' => OrderStatus.confirmed,
        'preparing' => OrderStatus.preparing,
        'ready' => OrderStatus.ready,
        'done' => OrderStatus.done,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.received,
      },
      items: [
        for (final i in json['items'] as List<dynamic>)
          OrderItem(
            productId: (i as Map<String, dynamic>)['productId'] as String,
            productSlug: i['productSlug'] as String? ?? '',
            name: i['productName'] as String,
            quantity: i['quantity'] as int,
            unitPrice: i['unitPrice'] as int,
            includedNames: [
              for (final n in (i['includedNames'] as List<dynamic>? ?? []))
                n as String,
            ],
            modifiers: [
              for (final m in (i['modifiers'] as List<dynamic>? ?? []))
                cartModifierFromOrderJson(m as Map<String, dynamic>),
            ],
          ),
      ],
      paymentMethod: switch (payment?['method'] as String?) {
        'transfer' => AdminPaymentMethod.transfer,
        // El enum backend es cash|transfer|gateway — Nequi llega como
        // 'gateway' con provider='nequi' (verificado contra el DTO real
        // en la integración §038); 'nequi' por compat con fixtures.
        'gateway' || 'nequi' => AdminPaymentMethod.nequi,
        _ => AdminPaymentMethod.cash, // 'cash' + null legacy defensivo
      },
      paymentStatus: switch (payment?['status'] as String?) {
        'paid' => OrderPaymentStatus.paid,
        'failed' => OrderPaymentStatus.failed,
        _ => OrderPaymentStatus.pending,
      },
      subtotal: json['subtotal'] as int,
      deliveryFee: json['deliveryFee'] as int,
      placedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      statusChangedAt: statusChangedAt == null
          ? null
          : DateTime.parse(statusChangedAt).toLocal(),
      tableLabel: json['tableLabel'] as String?,
      customerName: json['customerName'] as String?,
      cancelReason: json['cancelReason'] as String?,
      addressLabel: json['deliveryAddressLabel'] as String?,
      landmark: landmark,
      neighborhood: json['deliveryNeighborhood'] as String?,
      hasLocationPin: link != null,
      contactPhone: json['contactPhone'] as String?,
      note: json['notes'] as String?,
      locationUrl: link,
    );
  }
}
```

## 2. `i_admin_remote_datasource.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart`

```dart
import '../../models/admin_order_model.dart';

/// Puerto remoto de la cola del local (GET /admin/orders — backend §019).
/// El envelope {items,total,page,limit}: `active` no pagina (page/limit se
/// ignoran ahí); `history` sí (la pantalla provisional consume página 1).
abstract class IAdminRemoteDataSource {
  Future<({List<AdminOrderModel> items, int total})> fetchQueuePage(
    String bucket, {
    int? page,
    int? limit,
  });
}
```

## 3. `admin_remote_datasource_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart`

```dart
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/admin_order_model.dart';
import '../interfaces/i_admin_remote_datasource.dart';

/// SOLID (SRP): solo llama GET /admin/orders y parsea — el Bearer lo pone
/// el AuthInterceptor (rol admin lo exige el RolesGuard del backend), los
/// errores los traduce el repository. Espejo de OrdersRemoteDataSourceImpl.
class AdminRemoteDataSourceImpl implements IAdminRemoteDataSource {
  const AdminRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<({List<AdminOrderModel> items, int total})> fetchQueuePage(
    String bucket, {
    int? page,
    int? limit,
  }) async {
    final response = await _networkService.get(
      '/admin/orders',
      queryParameters: {'bucket': bucket, 'page': ?page, 'limit': ?limit},
    );
    final envelope = response as Map<String, dynamic>;
    return (
      items: (envelope['items'] as List<dynamic>)
          .map((o) => AdminOrderModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      total: envelope['total'] as int,
    );
  }
}
```

## 4. `admin_failure.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/domain/failures/admin_failure.dart`

```dart
import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de Cocina — el repository
/// impl traduce NetworkException; la UI elige el mensaje (convención
/// OrdersFailure/CheckoutFailure).
sealed class AdminFailure extends Equatable {
  const AdminFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad.
final class AdminOfflineFailure extends AdminFailure {
  const AdminOfflineFailure();
}

/// 4xx/5xx o inesperado — `message` se conserva para logging; la UI
/// siempre muestra su propio texto l10n.
final class AdminServerFailure extends AdminFailure {
  const AdminServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

## 5. `i_admin_repository.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/domain/repositories/i_admin_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';

/// Tamaño de página del historial admin (convención orders §027).
const kAdminHistoryPageSize = 20;

/// Una página del bucket history — items + total del servidor.
class AdminHistoryPage {
  const AdminHistoryPage({required this.items, required this.total});

  final List<AdminOrder> items;
  final int total;
}

/// Puerto del repositorio de Cocina (GET /admin/orders por bucket).
abstract class IAdminRepository {
  /// Bucket `active`: en curso + done sin cerrar (no pagina).
  Future<Either<AdminFailure, List<AdminOrder>>> getActiveOrders();

  /// Bucket `history`: cancelados + done cerrados, paginado.
  Future<Either<AdminFailure, AdminHistoryPage>> getHistoryOrders(int page);
}
```

## 6. `admin_repository_impl.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/data/repositories/admin_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/failures/admin_failure.dart';
import '../../domain/repositories/i_admin_repository.dart';
import '../datasources/interfaces/i_admin_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → AdminFailure (la UI nunca ve excepciones crudas) —
/// el mismo `_guard` genérico de OrdersRepositoryImpl.
class AdminRepositoryImpl implements IAdminRepository {
  const AdminRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final IAdminRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<AdminFailure, List<AdminOrder>>> getActiveOrders() =>
      _guard(() async => (await _remoteDataSource.fetchQueuePage('active')).items);

  @override
  Future<Either<AdminFailure, AdminHistoryPage>> getHistoryOrders(int page) =>
      _guard(() async {
        final res = await _remoteDataSource.fetchQueuePage(
          'history',
          page: page,
          limit: kAdminHistoryPageSize,
        );
        return AdminHistoryPage(items: res.items, total: res.total);
      });

  /// Red de seguridad idéntica a la de orders: un 200 malformado (cast del
  /// datasource) no es NetworkException — sin el catch de respaldo la UI
  /// quedaría en loading para siempre.
  Future<Either<AdminFailure, T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const Left(AdminOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(AdminServerFailure(e.toString()));
    }
  }

  AdminFailure _mapFailure(NetworkException e) => e is NoConnectionException
      ? const AdminOfflineFailure()
      : AdminServerFailure(e.message);
}
```

## 7. `load_admin_queue_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/domain/use_cases/load_admin_queue_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Resultado de la carga de Cocina — cada pierna degrada por separado
/// (la cola puede llegar aunque el historial falle, y viceversa; misma
/// convención de OrdersDataResult §027).
class AdminQueueData {
  const AdminQueueData({required this.active, required this.history});

  final Either<AdminFailure, List<AdminOrder>> active;
  final Either<AdminFailure, AdminHistoryPage> history;
}

/// SOLID (SRP): carga inicial / pull-to-refresh / reload al entrar al tab —
/// bucket active + página 1 del historial en paralelo.
class LoadAdminQueueUseCase {
  const LoadAdminQueueUseCase(this._repo);

  final IAdminRepository _repo;

  Future<AdminQueueData> call() async {
    final results = await Future.wait([
      _repo.getActiveOrders(),
      _repo.getHistoryOrders(1),
    ]);
    return AdminQueueData(
      active: results[0] as Either<AdminFailure, List<AdminOrder>>,
      history: results[1] as Either<AdminFailure, AdminHistoryPage>,
    );
  }
}
```

## 8. `order_item_modifier_mapper.dart` (archivo nuevo — extracción compartida)

**Ruta:** `lib/features/orders/data/models/order_item_modifier_mapper.dart`

El `_modifierFromJson` privado de `CustomerOrderModel` se extrae a función
top-level compartida — el snapshot `modifiers[]` del DTO tiene UNA sola
interpretación y hoy la necesitan dos parsers (`CustomerOrderModel` y
`AdminOrderModel`). Contenido = el cuerpo actual de `_modifierFromJson`,
verbatim, renombrado:

```dart
import '../../../cart/domain/entities/cart_modifier.dart';

/// Fila de modifier del OrderItemResponseDto → CartModifier (§016) —
/// group desde el slug del snapshot con las mismas reglas del detalle
/// del producto: removed y la fila del reemplazo siempre `ingredient`;
/// added por slug; null legacy → `extra` (fallback documentado).
CartModifier cartModifierFromOrderJson(Map<String, dynamic> m) {
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
```

## 9. `customer_order_model.dart` (archivo existente — actualización)

**Ruta:** `lib/features/orders/data/models/customer_order_model.dart`

**Antes:** el método estático `_modifierFromJson` (líneas ~88-109) y su uso
en `fromJson` (`_modifierFromJson(m as Map<String, dynamic>)`).

**Después:** se elimina `_modifierFromJson`; `fromJson` usa la función
compartida con el import nuevo:

```dart
import 'order_item_modifier_mapper.dart';
// ...
            modifiers: [
              for (final m in (i['modifiers'] as List<dynamic>? ?? []))
                cartModifierFromOrderJson(m as Map<String, dynamic>),
            ],
```

(El comentario del bloque modifiers/documentación queda igual — el
comportamiento es verbatim el mismo.)

## 10. `admin_order.dart` (archivo existente — actualización)

**Ruta:** `lib/features/admin/domain/entities/admin_order.dart`

**Antes (constructor + campos):**

```dart
    this.locationUrl,
    this.statusChangedAt,
  });
```

**Después:**

```dart
    this.locationUrl,
    this.statusChangedAt,
    this.orderNumber,
  });
```

Agregar el campo y el getter (tras `statusChangedAt`):

```dart
  /// Correlativo humano del pedido (campo `orderNumber` del DTO — el
  /// identificador corto que el dueño usa para hablar del pedido).
  /// Null en mocks/viejos sin el campo.
  final int? orderNumber;

  /// Tag corto del header ("#adm-N" — formato aprobado §037): con
  /// correlativo real muestra 'adm-N'; sin él cae a la cola del id
  /// (UUID recortado a 6 caracteres; un id mock corto se muestra
  /// completo). Reemplaza al static shortId del header.
  String get shortTag => orderNumber != null
      ? 'adm-$orderNumber'
      : (id.length <= 6 ? id : id.substring(id.length - 6));
```

`copyWith` y `props` agregan `orderNumber` (passthrough + entrada en props).

## 11. `admin_queue_cubit.dart` (archivo existente — actualización mayor)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_cubit.dart`

**Constructor — Antes:**

```dart
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({List<AdminOrder>? mockActive, List<AdminOrder>? mockHistory})
    : _mockActive = mockActive != null ? List.of(mockActive) : _defaultActive(),
      _mockHistory = mockHistory != null ? List.of(mockHistory) : _defaultHistory(),
      super(const AdminQueueState());

  final List<AdminOrder> _mockActive;
  final List<AdminOrder> _mockHistory;
```

**Después:**

```dart
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({required LoadAdminQueueUseCase loadQueue})
    : _loadQueue = loadQueue,
      super(const AdminQueueState());

  final LoadAdminQueueUseCase _loadQueue;
```

(Docstring de clase: quitar "solo presentación… datos ficticios" → "GET
/admin/orders del backend §019/022 — la cola sale de mocks §038".)

**`load()` — Antes:**

```dart
      emit(state.copyWith(dataLoading: state.isEmpty, failed: false));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (isClosed) return;
      emit(
        state.copyWith(
          active: _mockActive,
          history: _mockHistory,
          dataLoading: false,
        ),
      );
```

**Después:**

```dart
      emit(state.copyWith(dataLoading: state.isEmpty, failed: false));
      final result = await _loadQueue();
      if (isClosed) return;
      result.active.fold(
        // La cola NO se vacía en un refresh fallido — el banner de error
        // viaja sobre los datos viejos (kanban: perder la bandeja ante un
        // fallo de red es peor que mostrar datos stale + aviso). Sin datos
        // previos el mismo flag muestra la vista de error completa.
        (_) => emit(state.copyWith(dataLoading: false, failed: true)),
        (orders) => emit(
          state.copyWith(active: orders, dataLoading: false, failed: false),
        ),
      );
      result.history.fold(
        // Historial provisional (pantalla del ícono) — su falla no tiene
        // superficie visual hoy; conserva los datos previos en silencio.
        (_) {},
        (page) => emit(state.copyWith(history: page.items)),
      );
```

**Mutaciones — PROVISIONAL:**

`advanceOrder`, `markPaid`, `cancelOrder` se quedan mutando solo el estado
(su lógica no cambia — sigue siendo la simulación local aprobada); al docstring
de `_mutateOrder` se agrega:

```dart
/// PROVISIONAL (§038): las operaciones mutan SOLO el estado local hasta
/// sus ciclos de integración — PATCH /admin/orders/:id/status,
/// POST /admin/orders/:id/confirm-payment. El delay simulado se quita
/// cuando el endpoint responda de verdad.
```

`_mutateOrder`: se elimina el `await Future.delayed(_actionLatency)` y las
llamadas a `_syncMocks()`; se borran `_actionLatency`, `_syncMocks`,
`_defaultActive()` y `_defaultHistory()` **moviendo las dos últimas
verbatim** al archivo de fixtures de test (sección 14). `closeDay` también
pierde su `_syncMocks()` y el delay — queda PROVISIONAL igual (la mutación
local sobre el estado sigue siendo la simulación del cierre).

> **Nota sobre la latencia mock**: al quitar el delay las operaciones son
> instantáneas — visualmente el spinner inline deja de verse. Es el
> comportamiento correcto de la fase (la latencia real la pone el HTTP en
> el siguiente ciclo); si al probar en el emulador el cambio se siente
> "seco", se puede dejar un delay mínimo (150ms) PROVISIONAL — decisión del
> usuario en la revisión.

## 12. `admin_order_detail_header.dart` (archivo existente — actualización)

**Ruta:** `lib/features/admin/presentation/widgets/order_detail/admin_order_detail_header.dart`

**Antes:**

```dart
  /// Cola del id para el tag "#id" — 6 caracteres bastan para
  /// distinguir pedidos del día (los UUID del backend son largos);
  /// un id corto (los mocks 'adm-N') se muestra completo.
  static String shortId(String id) =>
      id.length <= 6 ? id : id.substring(id.length - 6);
```

**Después:** se elimina el static (la lógica vive en `AdminOrder.shortTag`).

**Antes:** `tag: l10n.adminOrderShortId(shortId(order.id)),`
**Después:** `tag: l10n.adminOrderShortId(order.shortTag),`

## 13. `setup_di.dart` (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
  locator.registerLazySingleton<AdminQueueCubit>(() => AdminQueueCubit());
```

**Después:**

```dart
  // Cocina admin (§038) — datasource → repo → use case → cubit singleton.
  locator.registerLazySingleton<IAdminRemoteDataSource>(
    () => AdminRemoteDataSourceImpl(networkService: locator()),
  );
  locator.registerLazySingleton<IAdminRepository>(
    () => AdminRepositoryImpl(
      remoteDataSource: locator(),
      networkInfo: locator(),
    ),
  );
  locator.registerLazySingleton<LoadAdminQueueUseCase>(
    () => LoadAdminQueueUseCase(locator()),
  );
  locator.registerLazySingleton<AdminQueueCubit>(
    () => AdminQueueCubit(loadQueue: locator()),
  );
```

+ los imports correspondientes.

## 14. Fixtures + tests

**`test/features/admin/fixtures/admin_order_fixtures.dart` (nuevo):**
los métodos `_defaultActive()`/`_defaultHistory()` del cubit se mueven
**verbatim** renombrados a funciones top-level
`List<AdminOrder> adminActiveFixtures()` / `adminHistoryFixtures()`, más:

```dart
/// Use case falso para tests de cubit/pantallas — devuelve las listas
/// dadas envueltas en el resultado (convención: fixtures + mocktail).
class FakeLoadAdminQueueUseCase extends Mock
    implements LoadAdminQueueUseCase {}

/// Cubit listo para tests: `load()` devuelve las fixtures (o las listas
/// inyectadas) — sustituye al viejo `AdminQueueCubit(mockActive:…)`.
AdminQueueCubit buildAdminQueueCubit({
  List<AdminOrder>? active,
  List<AdminOrder>? history,
  AdminFailure? activeFailure,
  AdminFailure? historyFailure,
}) {
  final useCase = FakeLoadAdminQueueUseCase();
  when(useCase.call).thenAnswer(
    (_) async => AdminQueueData(
      active: activeFailure != null
          ? Left(activeFailure)
          : Right(active ?? adminActiveFixtures()),
      history: historyFailure != null
          ? Left(historyFailure)
          : Right(
              AdminHistoryPage(
                items: history ?? adminHistoryFixtures(),
                total: (history ?? adminHistoryFixtures()).length,
              ),
            ),
    ),
  );
  return AdminQueueCubit(loadQueue: useCase);
}
```

**`admin_order_model_test.dart` (nuevo)** — JSON del doc 001 → entidad:
- mapeo completo delivery online (channel, dirección desglosada, link→
  locationUrl+hasLocationPin, contactPhone, notes→note, statusChangedAt)
- `dine_in` presencial con tableLabel, payment null → cash+pending
- `pending`→received y status desconocido → received (nunca terminal)
- fallback landmark = deliveryAddress crudo cuando los tres desgloses son null
- modificadores viajan por el mapper compartido (removed+added+grupos)

**`admin_repository_impl_test.dart` (nuevo)** — `_guard`: offline →
AdminOfflineFailure; ServerException → AdminServerFailure; cast roto →
AdminServerFailure (no loading eterno); éxito active/history.

**`load_admin_queue_use_case_test.dart` (nuevo)** — piernas paralelas:
ambas Right; active Right + history Left degrada sin tumbar la otra.

**`admin_queue_cubit_test.dart` (actualización)** — el cubit ya no acepta
mocks: `build:` usa `buildAdminQueueCubit` de fixtures. Cambios clave:
- "load() emite cargando → cola" igual pero ahora aserción sobre fixtures.
- Nuevo: "load() con falla activa → failed:true conservando datos previos"
  (cargar bien, luego stub que falla en el siguiente load, pull-to-refresh).
- Las pruebas de mutación (advance/markPaid/cancel/closeDay/preview) quedan
  IGUAL — siguen siendo locales PROVISIONAL sobre el estado.

**Screen tests (4 archivos)** — reemplazar `AdminQueueCubit()` /
`AdminQueueCubit(mockActive: …, mockHistory: …)` por `buildAdminQueueCubit(…)`
de fixtures. Los asserts visuales no cambian (los datos son los mismos).

---

## Fuera de alcance (otros ciclos)

- `PATCH /admin/orders/:id/status` (advance/cancel reales + manejo 409).
- `POST /admin/orders/:id/confirm-payment` (markPaid real).
- `GET/POST /admin/day-close` (preview + cierre reales).
- Paginación del historial admin + pantalla de historial definitiva.
- Pull-to-refresh automático / polling — `load()` corre por visita al tab
  y por pull manual, como hoy.

## Verificación

- `flutter analyze` limpio, `flutter test` completo verde.
- Verificación manual contra el backend real (`:3000`): login admin →
  Cocina muestra pedidos reales por carril, ordenados por statusChangedAt;
  sin backend/caido → vista de error con reintento (o banner con datos).

---

## Orden de aplicación

1. `order_item_modifier_mapper.dart` (nuevo) + `customer_order_model.dart`
2. `admin_order.dart` (orderNumber + shortTag) + `admin_order_detail_header.dart`
3. `admin_failure.dart` → `admin_order_model.dart` → datasource (interfaz + impl)
4. `i_admin_repository.dart` → `admin_repository_impl.dart` → `load_admin_queue_use_case.dart`
5. `admin_queue_cubit.dart` (use case + load real + mocks fuera)
6. `setup_di.dart`
7. Fixtures + tests nuevos + actualización de los 5 archivos de test
8. `flutter gen-l10n` NO aplica (sin textos nuevos) · `flutter analyze` + `flutter test`
9. Verificación manual contra el backend real
