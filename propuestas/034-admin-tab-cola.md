# Propuesta: UI admin — tab "Cocina" + cola de pedidos (presentación)

El backend del panel del dueño ya existe y está probado (§019):
`GET /admin/orders` (buckets active/history), `PATCH /admin/orders/:id/status`,
`POST /admin/orders/:id/confirm-payment`, `POST /admin/orders` (presencial),
`GET /admin/tables` — todo bajo `@Roles('admin')`. La app aún no tiene
dónde mostrarlo: un cliente puede pedir y "pagar" pero el dueño no ve
llegar el pedido. Sin esta UI el negocio no opera.

## Decisión del usuario (ya tomada — mock A vs B comparado en emulador)

**Entrada = 4º tab en la NavigationBar**, visible solo con sesión admin.

Razonamiento del dueño: "lo que menos voy a hacer es pedir como cliente;
lo que sí voy a hacer es órdenes manuales — no lo quiero escondido, lo
quiero a UN clic". Su teléfono opera como la caja del local: la cola y
la orden presencial son la pantalla de trabajo diaria, no una sección
del perfil.

Se descartó: fila "Panel del negocio" dentro de Perfil (opción A — 2
toques + scroll de distancia) y ruta oculta (opción C — ni siquiera el
dueño la descubriría).

## Alcance de ESTE ciclo (presentación — screen-first)

Ciclo 1 = la entrada por rol + la pantalla de la cola con mocks.
Integración por endpoint en los ciclos siguientes (mismo patrón que
Órdenes §026→§027 y Perfil §030→§032+).

### 1. Rama 4 + destino condicional por rol

- `app_router.dart`: `StatefulShellRoute.indexedStack` gana una 4ª rama
  `/admin` (raíz = cola). Las ramas son estáticas — la rama existe para
  todos; lo que cambia es si el DESTINO se dibuja.
- `app_shell_layout.dart`: los `destinations` del NavigationBar se
  construyen según `session.currentUser?.role == 'admin'` → 4 destinos
  para el dueño (Inicio·Pedidos·Perfil·**Cocina**), 3 para el resto.
  El layout envuelve el bar en `ListenableBuilder(listenable: session)`
  — aparece/desaparece en vivo al login/logout sin reiniciar.
- Caso borde: admin cierra sesión estando EN el tab admin → destinos
  vuelven a 3 con `currentIndex == 3` fuera de rango → en el builder,
  si `!isAdmin && shell.currentIndex > 2` se agenda `goBranch(0)`
  post-frame (mismo cuidado que el PopScope: no mutar durante build).

### 2. Guard por rol (AuthGuard gana la 2ª dimensión)

Hoy el guard solo sabe "¿hay sesión?". §034 agrega "¿es admin?":

| Ruta | Invitado | Cliente | Admin |
|------|----------|---------|-------|
| `/admin` + hijas | ⛔ → `/login?from=/admin` | ⛔ → `/home` | ✅ |

- `adminPrefixes = {'/admin'}` — default público sigue; estos prefijos
  exigen sesión **y** `role == 'admin'`.
- Invitado → login con retorno (un link de WhatsApp a un pedido admin
  debe poder aterrizar tras login).
- Cliente autenticado sin rol → `/home` (no "error" — simplemente esa
  superficie no es suya; el tab tampoco se dibuja para él).

### 3. Pantalla cola — `features/admin/`

Mismo patrón de casa (OrdersScreen §027 como hermana cercana):
franja firma + título "Cocina" naciendo del scroll + filtro
segmentado **Activos | Historial** + lista de cards + FAB.

Card de pedido admin (campos reales de `AdminOrderResponseDto` —
ya incluye lo que la vista cliente oculta: `channel`, `tableLabel`,
`customerName`):

- Chip canal: **Online** / **Presencial**
- Cliente: nombre o "En el local · Mesa N" (`tableLabel`)
- Resumen ítems (línea tipo "2× El Depredador + 1× Papas" — la casa ya
  tiene este formato en order cards)
- Total + método (Efectivo/Transferencia) + chip estado pago
- Chip estado: Pendiente / Confirmado / Listo (tonos del design system)
- Tiempo transcurrido ("hace 12 min")

Estados: skeleton de carga, vacío ("Sin pedidos activos — la cocina
descansa"), error + reintentar. Pull-to-refresh (la cola se re-consulta
— paridad con OrdersScreen §027 que recarga por visita).

**FAB "Nueva orden"** — el CTA del dueño según su decisión ("ordenes
manuales a un clic"): ancla visual desde el ciclo 1 aunque el form
llegue en el ciclo 3 — tap muestra toast "Disponible próximamente"
(patrón de mocks fase 1).

Tap en card → toast "Detalle en el próximo ciclo" (la hija de detalle
con las acciones pending→confirmed→done / "me pagó" es el ciclo 2 —
no inflar este).

### 4. Tab: label "Cocina" + ícono

`NavigationDestination` con `Icons.soup_kitchen_outlined/rounded`
(el del mock B que el usuario aprobó visualmente) y label **"Cocina"**.
Queda a criterio del `revisor-estetico` si el glifo/letra necesita otro
tratamiento — el usuario ya vio esta combinación y la prefirió.

## Archivos

| Archivo | Cambio |
|---------|--------|
| `lib/core/routes/app_router.dart` | 4ª rama `/admin` en el shell |
| `lib/core/routes/auth_guard.dart` | `adminPrefixes` + check de rol (nueva dimensión del guard) |
| `lib/core/layout/app_shell_layout.dart` | `ListenableBuilder(session)` + destinations condicionales + guardia `currentIndex > 2` |
| `lib/features/admin/presentation/screens/admin_queue_screen.dart` | pantalla cola (nueva) |
| `lib/features/admin/presentation/widgets/` | card pedido admin, chip canal/estado, segmented filter (nuevos, siguiendo file-size-refactoring) |
| `lib/features/admin/presentation/cubit/` | AdminQueueCubit mock fase 1 (patrón OrdersCubit §026) |
| `lib/l10n/*.arb` | claves: tab, título, filtros, chips, vacío/error, toasts mock |
| tests | guard por rol, destinations 3↔4, swap en login/logout, specs de la cola |
| `Design/design-system.yaml` | bump + spec shell (4º destino por rol) + spec cola admin |

## Fuera de alcance (roadmap documentado)

- Ciclo 2: detalle del pedido admin + acciones (status, confirm-payment)
- Ciclo 3: form "Nueva orden" presencial (ítems, dine_in/pickup, mesa,
  pago) contra `POST /admin/orders` + `GET /admin/tables`
- Integración real de la cola (`GET /admin/orders`) — puede adelantarse
  como ciclo 1b si la presentación se aprueba rápido
- Mesas como superficie propia (hoy solo `tableLabel` dentro del pedido)

## Verificación

- `flutter analyze` limpio + suite completa
- Tests: guard rechaza `/admin` a invitado (→ login) y a cliente
  (→ home), acepta admin; shell muestra 3↔4 destinos según rol y en
  vivo; logout en tab admin → cae a Inicio sin crash
- Emulador: login `dueno@depredadog.com` → 4º tab aparece en vivo;
  recorrer cola con mocks; revisor-estetico + revisor-ui sobre capturas
- Commit solo tras aprobación visual del usuario
