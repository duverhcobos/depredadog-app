# Propuesta 039: detalle admin — `GET /admin/orders/:id` al abrir

El listado `GET /admin/orders` manda `modifiers: []` a propósito (payload
liviano del kanban). El backend 023 (`GET /admin/orders/:id`, commit
`6761f11`) devuelve la comanda completa — "sin cebolla" es instrucción de
cocina. La pantalla ya resuelve la orden viva por id del cubit
(`state.orderById(order.id) ?? order`), así que el fetch solo tiene que
**inyectar la orden completa en el state** y el detalle se re-renderiza
solo — con status fresco además (pudo cambiar desde que se listó).

Sin cambios visuales: `AdminOrderDetailItems` ya auto-expande modifiers
cuando `item.modifiers.isNotEmpty` — aparecen solos al llegar la orden
completa.

## Contrato

`GET /admin/orders/:id` → 200 `AdminOrderResponseDto` (misma forma del
listado, modifiers poblados) · 400 · 401 · 403 · 404 `ORDER_NOT_FOUND`.

## Archivos

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart` | + `fetchAdminOrder(id)` |
| `lib/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart` | + impl (`GET /admin/orders/:id` → `AdminOrderModel.fromJson`) |
| `lib/features/admin/domain/repositories/i_admin_repository.dart` | + `getOrderDetail(id)` |
| `lib/features/admin/data/repositories/admin_repository_impl.dart` | + impl (mismo `_guard` Either de §038; 404 → `AdminServerFailure`) |
| `lib/features/admin/domain/use_cases/get_admin_order_detail_use_case.dart` | **nuevo** — delega al repo |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | + `refreshOrder(id)` — inyecta la orden en el state |
| `lib/features/admin/presentation/screens/admin_order_detail_screen.dart` | Stateless→Stateful: `initState` dispara `refreshOrder` |
| `lib/core/di/setup_di.dart` | + provider del use case |
| `test/features/admin/...` | spec del use case + tests de `refreshOrder` en el cubit + ajuste del test de pantalla si el Stateful cambia el harness |

## 1. Datasource

```dart
Future<AdminOrderModel> fetchAdminOrder(String orderId) async {
  final response = await _networkService.get('/admin/orders/$orderId');
  return AdminOrderModel.fromJson(response.data as Map<String, dynamic>);
}
```

## 2. Repository

```dart
Future<Either<AdminFailure, AdminOrder>> getOrderDetail(String orderId);
```

Impl: `_guard(() => ds.fetchAdminOrder(id))` — misma envoltura de §038
(offline → `AdminOfflineFailure`, resto → `AdminServerFailure`).

## 3. Use case — `get_admin_order_detail_use_case.dart`

```dart
class GetAdminOrderDetailUseCase {
  const GetAdminOrderDetailUseCase(this._repository);
  final IAdminRepository _repository;
  Future<Either<AdminFailure, AdminOrder>> call(String orderId) =>
      _repository.getOrderDetail(orderId);
}
```

## 4. `AdminQueueCubit.refreshOrder(id)`

```dart
/// GET /admin/orders/:id (§039) — al abrir el detalle: la comanda
/// completa (modifiers) + estado fresco reemplazan el snapshot del
/// listado. Falla silenciosa: el detalle ya muestra el snapshot.
Future<void> refreshOrder(String id) async {
  final result = await _getOrderDetail(id);
  result.fold((_) {}, (full) {
    final inActive = state.active.any((o) => o.id == id);
    if (inActive) {
      emit(state.copyWith(
          active: [for (final o in state.active) o.id == id ? full : o]));
      return;
    }
    if (state.history.any((o) => o.id == id)) {
      emit(state.copyWith(
          history: [for (final o in state.history) o.id == id ? full : o]));
    }
    // No está en ninguna bandeja (history solo carga página 1): se
    // ignora — el detalle sigue con el snapshot del extra.
  });
}
```

- Sin `busyOrderIds` — es refresh de fondo, no mutación.
- Falla **silenciosa**: el detalle ya renderiza el snapshot; un toast por
  modifiers ausentes sería ruido (si el backend cayó, el banner de la
  cola ya lo dice en el siguiente `load()`).

## 5. Pantalla — StatefulWidget

`AdminOrderDetailScreen` pasa a `StatefulWidget`; en `initState`:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<AdminQueueCubit>().refreshOrder(widget.order.id);
});
```

(post-frame: el cubit es singleton del shell — `context.read` seguro;
cubre cualquier entry point, no solo el tap de la card.)

## 6. DI

`setup_di.dart`: `GetAdminOrderDetailUseCase(sl())` junto a
`LoadAdminQueueUseCase`; el cubit lo recibe por constructor (nuevo param
tras `_loadQueue`, default-friendly para tests vía fixture).

## 7. Tests

- `get_admin_order_detail_use_case_test.dart`: Right/Left delegando.
- `admin_repository_impl_test`: `getOrderDetail` → Right(modelo) con
  JSON con modifiers; failure mapping.
- `admin_queue_cubit_test`: `refreshOrder` reemplaza en `active`,
  reemplaza en `history`, no-op si no está, no-op si falla.
- Test de pantalla: verificar que al montar el detalle se llamó
  `refreshOrder` (mocktail `verify`) y que con modifiers en el state se
  ve el ítem auto-expandido.

## Orden de aplicación

1. Datasource + repository + use case (+ specs)
2. Cubit `refreshOrder` + constructor + DI
3. Pantalla → Stateful + initState
4. Tests del cubit y de pantalla
5. `flutter analyze` + `flutter test`

---

## Adición — carrera `refreshOrder` vs `load()` (hallada en verificación manual)

Un `load()` concurrente (re-entry del tab, pull del dueño) respondía
~20ms DESPUÉS del detalle y pisaba la orden hidratada con el snapshot
`modifiers:[]`. Fix: los ítems de una orden son inmutables — `load()`
conserva los ítems hidratados cuando el listado llega sin modifiers.

- `AdminOrder.copyWith` gana param opcional `items`.
- `AdminQueueCubit._preserveHydratedItems(incoming)`: si la copia previa
  tiene modifiers y la entrante no, hereda `prev.items` — aplicado al
  emit de `active` y al de `history`.
- Test nuevo: load() posterior no pisa la orden hidratada.

**Auto-expand post-hidratación (revisor):** `_ItemLine.didUpdateWidget`
— un ítem que GANA modifiers al hidratarse se auto-expande aunque nació
colapsado con solo incluidos (el shape real del listado: `includedNames`
sí viajan, `modifiers` no). Sin esto "sin cebolla" quedaba tras un toque.

**Limitaciones conocidas → ciclo PATCH status/confirm-payment:**
- `refreshOrder` en vuelo + mutación local puede pisar status/pago con
  el dato del servidor hasta el próximo `load()` (las operaciones son
  PROVISIONAL — se resuelven al volverse server-authoritative).
- `refreshOrder` no migra entre bandejas si el `:id` devuelve terminal
  (se corrige solo en el próximo `load()`).
- `_preserveHydratedItems` puede perder la hidratación si la orden
  migró de bucket server-side entre el fetch y el load (ventana rara).
