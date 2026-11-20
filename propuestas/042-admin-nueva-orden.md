# Propuesta: Nueva orden presencial — comanda del dueño (App §042)

El FAB "+" de Cocina deja el placeholder y abre la **comanda del
local**: la pantalla con la que el dueño toma pedidos de mesa y de
mostrador y los manda directo a la cola kanban. Es la última pieza
operativa del módulo — cierra el pendiente app/013.

Contratos (verdad absoluta):
`documentacion/api/admin/004-post-admin-orders.md` (crear presencial:
`servicetype` dine_in|pickup, `tableId` obligatorio en dine_in,
`paymentMethod` cash|transfer, `payerPhone` exigido en transfer,
`items[]` con `optionId`+`action`+`replacesOptionId`) y
`005-get-admin-tables.md` (mesas con `isActive`/`activeOrderNumber`).

Reutilizaciones clave — nada se reinventa:
- `CartItem` + `CartModifier` (feature cart) modelan el armado del
  ítem y serializan 1:1 a `items[].modifiers` del POST.
- `GetCatalogMenuUseCase` (feature home) trae la carta real con
  `CatalogProduct.removableIngredients`/`additionalOptions`/
  `toppingOptions`/`sauceOptions`/`isSellable` ya calculados.
- `AdminOrderModel`/`AdminFailure`/`AdminQueueCubit.load()` de la
  integración §038-041 — el pedido creado aparece en la cola con el
  mismo `load()` de siempre.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/domain/entities/admin_table.dart` | **nuevo** — mesa + ocupación |
| `lib/features/admin/domain/entities/admin_new_order_draft.dart` | **nuevo** — borrador de la comanda (servicio/mesa/ítems/pago/nota) |
| `lib/features/admin/data/models/admin_table_model.dart` | **nuevo** |
| `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart` | +`fetchTables`, `createOrder` |
| `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart` | implementa los 2 endpoints |
| `lib/features/admin/domain/repositories/i_admin_repository.dart` | +`getTables`, `createInPersonOrder` |
| `lib/features/admin/data/repositories/admin_repository_impl.dart` | implementa los 2 (mismo `_guard`/`_mapFailure`; payload CartItem→API en data) |
| `lib/features/admin/domain/use_cases/load_admin_tables_use_case.dart` | **nuevo** |
| `lib/features/admin/domain/use_cases/create_admin_order_use_case.dart` | **nuevo** |
| `lib/features/admin/presentation/cubit/admin_new_order_{cubit,state}.dart` | **nuevo** — draft + 2 pasos internos + submit |
| `lib/features/admin/presentation/screens/admin_new_order_screen.dart` | **nuevo** — shell con SignatureStrip/título/step |
| `lib/features/admin/presentation/widgets/new_order/` | **nuevos** — `_ComandaStep`, `_ItemCustomizeSheet`, `_CobroStep` y piezas |
| `lib/core/routes/app_router.dart` | hija literal `orders/new` ANTES de `:id` |
| `lib/features/admin/presentation/screens/admin_queue_screen.dart` | FAB → `push` a la ruta (adiós toast provisional) |
| `lib/core/di/setup_di.dart` | `registerFactory` del cubit (borrador por visita) + 2 use cases |
| `lib/l10n/app_es.arb` | strings nuevos + `flutter gen-l10n` |
| tests | modelo tablas, datasource, repository, use cases, cubit, pantalla/sheet, fixtures |

## Decisiones de arquitectura (con contexto)

- **Cubit por visita**: `AdminNewOrderCubit` se registra con
  `registerFactory` y la ruta hace `BlocProvider(create:)` — el
  borrador nace y muere con la pantalla (no queda ticket fantasma de
  una comanda abandonada, a diferencia del singleton de la cola).
- **Una ruta, dos pasos internos**: `/admin/orders/new` con `step`
  en el state (`comanda` → `cobro`) en vez de dos rutas — evita el
  problema de compartir cubit entre rutas hermanas sin singleton y
  la transición queda dentro de la pantalla (misma filosofía del
  stepper de checkout del cliente).
- **`CartItem` como ítem del borrador**: el POST pide
  `{optionId, action, replacesOptionId}` por modificador — exactamente
  la forma de `CartModifier`. La comanda produce los mismos objetos
  que el carrito del cliente; la conversión a payload vive en el
  datasource (data conoce data).

## 1. admin_table.dart (entidad nueva)

**Ruta:** `lib/features/admin/domain/entities/admin_table.dart`

```dart
import 'package:equatable/equatable.dart';

/// Mesa del local (GET /admin/tables — backend §019): `label` es el
/// nombre visible ("Mesa 2"), `activeOrderNumber` el consecutivo del
/// pedido dine_in vivo — null = libre. Una mesa inactiva viaja pero
/// no acepta pedidos nuevos (TABLE_NOT_FOUND del backend).
class AdminTable extends Equatable {
  const AdminTable({
    required this.id,
    required this.label,
    required this.isActive,
    required this.activeOrderNumber,
  });

  final String id;
  final String label;
  final bool isActive;

  /// Consecutivo diario del pedido vivo ocupando la mesa — null libre.
  final int? activeOrderNumber;

  /// Seleccionable para una comanda nueva: activa Y sin pedido vivo.
  bool get isFree => isActive && activeOrderNumber == null;

  @override
  List<Object?> get props => [id, label, isActive, activeOrderNumber];
}
```

## 2. admin_new_order_draft.dart (entidad nueva)

**Ruta:** `lib/features/admin/domain/entities/admin_new_order_draft.dart`

```dart
import '../../../cart/domain/entities/cart_item.dart';
import 'admin_order.dart';

/// Borrador de la comanda presencial (§042) — el "qué se va a
/// crear" completo antes de mandar. Los ítems son `CartItem` del
/// feature cart: su `CartModifier` serializa 1:1 a
/// `items[].modifiers` del POST /admin/orders (mismo shape
/// `optionId`+`action`+`replacesOptionId` — no se traduce nada).
/// El teléfono solo tiene sentido en transfer (el contrato lo
/// exige ahí y lo prohíbe en cash); la mesa solo en dineIn.
class AdminNewOrderDraft {
  const AdminNewOrderDraft({
    required this.serviceType,
    required this.paymentMethod,
    required this.items,
    this.tableId,
    this.payerPhone,
    this.notes,
  });

  /// dineIn (mesa) | pickup (mostrador/para llevar) — delivery
  /// presencial no existe en el contrato.
  final AdminServiceType serviceType;
  final String? tableId;

  /// Efectivo | Transf. — presencial no admite Nequi gateway.
  final AdminPaymentMethod paymentMethod;
  final String? payerPhone;

  final List<CartItem> items;
  final String? notes;

  int get total => items.fold(0, (s, i) => s + i.lineTotal);
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);
}
```

## 3. AdminTableModel (modelo nuevo)

**Ruta:** `lib/features/admin/data/models/admin_table_model.dart`

```dart
import '../../domain/entities/admin_table.dart';

/// JSON de GET /admin/tables — un renglón por mesa.
class AdminTableModel extends AdminTable {
  AdminTableModel.fromJson(Map<String, dynamic> json)
    : super(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? false,
        activeOrderNumber: json['activeOrderNumber'] as int?,
      );
}
```

## 4. Datasource (interfaz + impl)

**`i_admin_remote_datasource.dart`** — se agregan:

```dart
  /// GET /admin/tables (§042 — backend §019): mesas con ocupación
  /// en vivo para el picker de la comanda.
  Future<List<AdminTableModel>> fetchTables();

  /// POST /admin/orders (§042 — backend §019): crea el presencial.
  /// `payload` ya viene en forma JSON del repo (serviceType, tableId?,
  /// items con modifiers, paymentMethod, payerPhone?, notes?). 201 →
  /// la vista admin completa; 400/404/409/502 salen como
  /// ServerException con errorCode.
  Future<AdminOrderModel> createOrder(Map<String, dynamic> payload);
```

**`admin_remote_datasource_impl.dart`** — se agregan:

```dart
  @override
  Future<List<AdminTableModel>> fetchTables() async {
    final json = await _network.get('/admin/tables');
    return [
      for (final t in (json['items'] as List? ?? const []))
        AdminTableModel.fromJson(t as Map<String, dynamic>),
    ];
  }

  @override
  Future<AdminOrderModel> createOrder(Map<String, dynamic> payload) async {
    final json = await _network.post('/admin/orders', data: payload);
    return AdminOrderModel.fromJson(json as Map<String, dynamic>);
  }
```

## 5. Repositorio (interfaz + impl)

**`i_admin_repository.dart`** — se agregan:

```dart
  /// Mesas del local con ocupación (§042 — picker de la comanda).
  Future<Either<AdminFailure, List<AdminTable>>> getTables();

  /// POST /admin/orders (§042): crea el presencial del borrador.
  /// dineIn→confirmed / pickup→pending según el backend.
  Future<Either<AdminFailure, AdminOrder>> createInPersonOrder(
    AdminNewOrderDraft draft,
  );
```

**`admin_repository_impl.dart`** — el payload se arma acá (data
conoce `CartItem`/`CartModifier`):

```dart
  @override
  Future<Either<AdminFailure, AdminOrder>> createInPersonOrder(
    AdminNewOrderDraft draft,
  ) => _guard(
    () => _remote.createOrder({
      'serviceType': draft.serviceType == AdminServiceType.dineIn
          ? 'dine_in'
          : 'pickup',
      if (draft.tableId != null) 'tableId': draft.tableId,
      'items': [
        for (final i in draft.items)
          {
            'productId': i.productId,
            'quantity': i.quantity,
            'modifiers': [
              for (final m in i.modifiers)
                {
                  'optionId': m.optionId,
                  'action': m.action.name,
                  if (m.replacesOptionId != null)
                    'replacesOptionId': m.replacesOptionId,
                },
            ],
          },
      ],
      'paymentMethod': draft.paymentMethod == AdminPaymentMethod.cash
          ? 'cash'
          : 'transfer',
      if (draft.payerPhone != null) 'payerPhone': draft.payerPhone,
      if (draft.notes != null && draft.notes!.trim().isNotEmpty)
        'notes': draft.notes!.trim(),
    }),
  );
```

(`getTables` passthrough con `_guard` igual que el resto.)

## 6-7. Use cases nuevos (espejo del patrón)

`load_admin_tables_use_case.dart` y `create_admin_order_use_case.dart`
— misma forma passthrough de §041 (reciben `IAdminRepository`, `call()`
delega; create recibe el `AdminNewOrderDraft`).

## 8. AdminNewOrderState + AdminNewOrderCubit (archivos nuevos)

**Ruta:** `lib/features/admin/presentation/cubit/admin_new_order_state.dart`

```dart
/// Estado de la comanda (§042): la carta + mesas cargadas una vez,
/// el borrador en construcción, y el paso interno
/// (comanda→cobro) en vez de ruta hermana.
enum AdminNewOrderStep { comanda, cobro }
```

Campos: `categories` (List<CatalogCategory>), `tables`
(List<AdminTable>), `loading`/`failed` (carga de carta+mesas),
`items` (List<CartItem> del borrador), `step`, `serviceType`
(default dineIn), `selectedTableId`, `paymentMethod`
(default cash), `payerPhone`, `notes`, `submitting`.
Derivados: `total`, `itemCount`, `selectedTable`,
`tableAvailable` (re-valida al cobrar), `canSubmit` = items no
vacío + (pickup | mesa libre elegida) + (cash | teléfono válido
`/3\d{9}$/`).

**Ruta:** `lib/features/admin/presentation/cubit/admin_new_order_cubit.dart`

```dart
/// Cubit de la comanda presencial (§042) — registrado como FACTORY:
/// cada entrada a /admin/orders/new obtiene un borrador limpio y el
/// abandonado muere con la pantalla (a diferencia del singleton de
/// la cola).
class AdminNewOrderCubit extends Cubit<AdminNewOrderState> {
  AdminNewOrderCubit({
    required GetCatalogMenuUseCase getMenu,
    required LoadAdminTablesUseCase loadTables,
    required CreateAdminOrderUseCase createOrder,
  }) : _getMenu = getMenu,
       _loadTables = loadTables,
       _createOrder = createOrder,
       super(const AdminNewOrderState());
```

Métodos: `load()` (menu+tables en paralelo — `Future.wait` sobre los
dos Either; Left en cualquiera → `failed`+error view con Reintentar
como la cola), `addItem(CartItem)` (merge por `sameConfiguration` —
misma regla del carrito: mismo producto+mismos mods suma qty, max 20
por el DTO), `removeItem(id)`/`setItemQty(id,qty)`, `toggleService`,
`selectTable(id)` (solo si `isFree`), `setPayment(method)`,
`setPayerPhone(v)`, `setNotes(v)`, `goToCobro()` (exige items),
`backToComanda()`, `submit()`:

```dart
  /// "Crear pedido" — POST /admin/orders (§042). Devuelve la orden
  /// creada o el failure para que la pantalla tostee por código:
  /// ORDER_CATALOG_VIOLATION (un ítem se agotó en el medio),
  /// TABLE_NOT_FOUND (la mesa quedó ocupada/inactiva → resync de
  /// mesas + elige otra), PAYMENT_DISPATCH_FAILED (el push transfer
  /// no salió) o genérico. El éxito lo muestra el load() de la cola.
  Future<AdminNewOrderSubmit> submit() async { ... }
```

(`submit()` devuelve un record `(AdminOrder? order, AdminFailure? failure)`
o enum sellado simple — convención del proyecto, a definir en impl:
preferir record ligero como `AdminHistoryPage`.)

## 9. Ruta + FAB

**`app_router.dart`** — hija literal ANTES de `:id` (misma regla del
comentario existente):

```dart
                  // Comanda presencial (§042) — cubit propio por
                  // visita (factory): el borrador muere al salir.
                  GoRoute(
                    path: 'orders/new',
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      BlocProvider(
                        create: (_) => locator<AdminNewOrderCubit>(),
                        child: const AdminNewOrderScreen(),
                      ),
                    ),
                  ),
```

**`admin_queue_screen.dart`** — el FAB deja el toast:

```dart
          FloatingActionButton(
            onPressed: () => context.push('${AuthGuard.adminRoute}/orders/new'),
            ...
```

## 10. admin_new_order_screen.dart + widgets (archivos nuevos)

Lenguaje: la familia admin ya establecida (SignatureStrip + título
naciente + footer fijo opaco — regla §035). Esqueleto:

```
Stack[SignatureStrip + Column[
  Expanded(AnimatedSwitcher/Pages del step):
    COMANDA → CustomScrollView:
      _ComandaTitle "Nueva orden" (patrón scrolling_title)
      chips de categoría (Todo + las de la carta, mismo SelectChip)
      lista de productos de la categoría: _ProductPickRow compacto
        (imagen asset por slug 56, nombre, precio, "+" o stepper
        qty cuando el ítem ya está en ticket; isSellable=false →
        fila atenuada "Agotado" sin tap)
      tap → _ItemCustomizeSheet (modal bottom sheet)
    COBRO → ListView:
      _CobroTitle "Revisar y cobrar"
      _TicketItems (filas qty stepper + quitar + nota visible)
      _ServiceSection: chips [Mesa | Para llevar] + grid de mesas
        (libres enabled, ocupada muestra #pedido y queda disabled,
        inactiva atenuada)
      _PaymentSection: chips [Efectivo | Transf.] + campo celular
        3XXXXXXXXX visible solo en Transf. (validación inline)
      _NoteField (opcional, maxLength 500)
  Footer fijo opaco (patrón §035):
    comanda → "N ítems · $total → Continuar" (disabled si 0)
    cobro   → "Crear pedido · $total" (spinner inline en busy)
]]
```

`_ItemCustomizeSheet` — sheet modal isScrollControlled:
header (foto+nombre+precio) + qty stepper + secciones compactas con
los mismos conceptos del cliente: "Se le quita" (chips toggle de
`removableIngredients`), "Le agregamos" (chips `additionalOptions`
con +$), "Toppings"/"Salsas" si el producto los tiene, opción
agotada → fila deshabilitada con tag "Agotado" (V1 sin flujo de
reemplazo — ver decisiones), nota del ítem FUERA de scope
(items[].notes no viaja en V1) → "Agregar · $X.XXX" que produce el
`CartItem` y cierra.

## 11. Errores del submit (mapa de la pantalla)

| errorCode | UX |
|-----------|-----|
| `ORDER_CATALOG_VIOLATION` (409) | toast `adminNewOrderCatalogViolation` "Un ítem ya no está disponible — revisa la comanda" + se queda |
| `TABLE_NOT_FOUND` (404) | `loadTables` resync + toast `adminNewOrderTableStale` "La mesa cambió — elige otra" + se queda |
| `PAYMENT_DISPATCH_FAILED` (502) | toast `adminNewOrderDispatchFailed` "No pudimos enviar el cobro — cobra en efectivo o inténtalo de nuevo" + se queda |
| offline/otro | toast `adminToastActionFailed` genérico + se queda |
| éxito | toast `adminNewOrderCreated(#N)` "Pedido #N en la cola" + pop a Cocina + `load()` resync (la card llega animada) |

## 12. l10n (keys nuevas — todas por AppLocalizations)

`adminNewOrderTitle` "Nueva orden" · `adminNewOrderContinue` "Continuar"
· `adminNewOrderItems` "{count} ítems" · `adminNewOrderCreate` "Crear
pedido" · `adminNewOrderCreated` "Pedido #{number} en la cola" ·
`adminNewOrderService` "Servicio" · `adminNewOrderDineIn` "Mesa" ·
`adminNewOrderPickup` "Para llevar" · `adminNewOrderPayment` "Pago" ·
`adminNewOrderPayerPhone` "Celular que recibe el cobro" ·
`adminNewOrderPhoneHint` "Ej: 3001234567" · `adminNewOrderPhoneError`
"Escribe el celular de 10 dígitos" · `adminNewOrderNote` "Nota del
pedido (opcional)" · `adminNewOrderTicketEmpty` "Toca un producto para
agregarlo" · `adminNewOrderTableBusy` "#{number}" · `adminNewOrderRemove`
"Quitar" · `adminNewOrderSheetAdd` "Agregar" · `adminNewOrderLoadError`
"No pudimos cargar la comanda" · `adminNewOrderCatalogViolation` ·
`adminNewOrderTableStale` · `adminNewOrderDispatchFailed` (textos del
mapa de errores) + sus metadatos `@`.

## 13. Tests

| Archivo | Cubre |
|---------|-------|
| `admin_table_model_test` (nuevo) | parse + `isFree` derivado |
| `admin_remote_datasource_impl_test` | GET /admin/tables; POST /admin/orders verbo+ruta+payload (modifiers con action/replacesOptionId, payerPhone solo en transfer) |
| `admin_repository_impl_test` | payload CartItem→API exacto; 400/404/409/502→failures con errorCode |
| use cases ×2 | passthrough |
| `admin_new_order_cubit_test` (nuevo) | load paralelo; addItem merge por sameConfiguration + tope 20; qty/remove; canSubmit por combinación (mesa obligatoria en dineIn, teléfono exigido en transfer); submit éxito/fallas |
| `admin_new_order_screen_test` (nuevo) | comanda: productos + filtro + sheet abre; cobro: mesas ocupadas disabled, transf revela teléfono, CTA disabled sin mesa/ítems; submit éxito → toast+pop+load; falla → toast+se queda |
| `admin_queue_screen_test` | FAB navega a la ruta nueva (adiós "próximamente") |
| fixtures | productos con modifierGroups + mesas libres/ocupadas/inactivas |

## Orden de aplicación

1. Entidades + modelo tabla
2. Datasource → repo → use cases ×2 → DI (factory del cubit)
3. State + cubit
4. Ruta + FAB + pantalla + widgets/sheet + l10n + gen-l10n
5. Tests + `flutter analyze` + `flutter test`
6. Verificación en emulador (comanda completa → pedido real en cola)

## Fuera de alcance

- **`items[].notes`** (nota por ítem) — `CartItem` no la modela; la
  nota del pedido completo sí viaja. Se evalúa después si el dueño
  la pide ("el de arriba sin picante" hoy va en la nota general).
- **Reemplazo de agotados** — V1 muestra la opción deshabilitada
  "Agotado"; el flujo `replacesOptionId` del cliente queda para una
  iteración si el dueño lo usa en el mostrador.
- **Pedido presencial a domicilio** — el endpoint no lo contempla
  (solo dine_in/pickup); un "por teléfono" se toma como pickup.
- **Editar/agregar a un pedido vivo** — la mesa ocupada no acepta
  segundo pedido; agregar a una comanda abierta es otro endpoint.
- **ClientRequestId** — el contrato lo excluye a propósito (el
  dueño ve la comanda al instante; doble-tap lo cubre el busy).

## Verificación manual esperada

Comanda real: "Mesa 2 · 1× El Coyote (sin cebolla) · Efectivo" →
POST 201 → la card aparece en Confirmado con la animación del diff
y el detalle muestra el modifier. Y "Para llevar · Transf. + celular"
→ nace en Pendiente con "Registrar pago" (puerta §041 intacta).
