# Pendiente: Refresh del catálogo en Home sin reiniciar la app

> **Estado: 🔴 ABIERTO**
> **Producto:** frontend
> **Severidad:** UX operativa — el dueño cambia precios/menú y la app instalada no lo refleja hasta matar el proceso

## Contexto

Reporte del dueño en prod (2026-11-20): tras el wipe + re-seed del menú real, la app seguía mostrando la carta vieja "ni regresándome ni volviendo a empezar de cero" — solo matar la app y reabrirla actualizó.

Causa técnica confirmada:

- `CatalogCubit` se registra como **`lazySingleton`** en `setup_di.dart` → el
  catálogo se pide una vez por sesión de proceso y queda en memoria.
- **No hay `RefreshIndicator` en ninguna pantalla de `home/`** — la cola de
  admin y Pedidos sí lo tienen (`AdminQueueCubit.load()` /
  `OrdersCubit.loadOrders()` en `onRefresh`), el home no.
- La pantalla "Nueva orden presencial" NO sufre esto: `AdminNewOrderCubit`
  es `registerFactory` y su `load()` llama `GetCatalogMenuUseCase` +
  `LoadAdminTablesUseCase` en vivo cada vez que se abre.

## Opciones (decidir en la propuesta que lo implemente)

- **Pull-to-refresh en Home** — `RefreshIndicator` sobre el scroll del home
  llamando `CatalogCubit.load()` (mismo patrón ya usado en cola/pedidos).
  Simple, convención existente.
- **Refetch al volver al tab / app resume** — `didChangeAppLifecycleState`
  o refetch al entrar a la branch home del shell si el state tiene >
  X minutos (staleness). Menos visible, cero gesto del usuario.
- **Ambas**: pull-to-refresh + refetch si data > 5 min.

Nota: `StoreConfigCubit` (horario/abierto/promos) probablemente tiene el
mismo problema — revisar su ciclo de vida en la misma propuesta.

## Criterio de cierre

- Cambiar el menú en la DB se refleja en el Home sin matar la app
  (pull-to-refresh o refetch automático verificable).
- Tests: el cubit re-emite con data nueva tras el segundo `load()`.
