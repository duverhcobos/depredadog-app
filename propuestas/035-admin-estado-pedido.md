# Propuesta: UI admin — cambio de estado híbrido (botón en card + detalle)

El tab "Cocina" ya muestra la cola con mocks (§034 — pendiente de commit
tras el gate visual del pulido: thumb deslizante + "+N más"). Lo que
**no** hace aún es lo esencial: cambiar el estado del pedido. Este ciclo
implementa la interacción **en presentación con mocks** (mismo patrón
screen-first) contra el contrato REAL del backend.

## Decisión del usuario (ya tomada — opciones presentadas)

**Híbrido: botón de avance en la card + detalle completo al tap.**

Razonamiento aceptado: el teléfono del dueño es herramienta de trabajo —
el 90% de las operaciones es avanzar el pedido un paso (un toque, sin
abrir nada); el detalle — que igual necesitamos para los ítems
completos, cancelar y marcar pago — queda a un tap para las acciones
raras. Lo destructivo (cancelar) solo vive en el detalle con
confirmación: el botón de la card **nunca** puede destruir.

Descartado: solo-detalle (un tap extra por pedido todo el día), swipe
(poco descubrible, se dispara solo), solo-botón (cancelar/pago sin
hogar claro). Nombre del tab: **se queda "Cocina"** (el usuario
rechazó las dos tandas de alternativas).

## Contrato real del backend (§019 — probado, no se toca)

```
PATCH /admin/orders/:id/status     {to, cancelReason?}
POST  /admin/orders/:id/confirm-payment    ← "me pagó" (claim atómico)
```

Matriz de transición (sin `preparing` — existe en el enum pero el
contrato nunca lo emite: `pending → confirmed → done`, + `cancelled`
desde cualquier no-terminal):

| Desde | Puede ir a |
|-------|-----------|
| pending | confirmed, cancelled |
| confirmed | done, cancelled |
| preparing | done, cancelled (inalcanzable por contrato — el mock lo cubre igual) |
| done / cancelled | — (terminal) |

**Invariante crítica:** `done` exige `payment.status == paid` → el
backend responde 409 `PaymentNotSettled` si no está cobrado. La UX debe
respetar ese orden: **no se entrega sin cobrar**.

## Alcance de ESTE ciclo (presentación — mocks, sin API)

### 1. Botón de acción en la card (cola)

Cada card activa gana una fila inferior con un `FilledButton` de ancho
completo — el área de toque más grande posible, la acción es el punto
de la pantalla. El label = la **siguiente acción real** según la
matriz estado×pago:

| Estado + pago | Botón | Efecto (mock) |
|---|---|---|
| pending | **"Confirmar"** | → confirmed |
| confirmed / preparing + `pending` | **"Me pagó"** | → payment=paid (done está bloqueado hasta cobrar — la siguiente acción real ES cobrar) |
| confirmed / preparing + `paid` | **"Listo"** | → done (sale de activos → historial) |
| done / cancelled | — | sin botón (historial: la card queda de solo lectura) |

- Un toque, **sin confirmación** para avanzar/cobrar (no destructivo;
  equivocarse se corrige fácil). Solo "Cancelar" pide confirmación, y
  solo vive en el detalle.
- Mientras la acción mock corre (~400ms como `load`), el botón muestra
  un spinner inline — el mismo estado ocupado que luego evitará el
  doble-tap contra el UPDATE condicional del backend (affected=0 → 409).
- La card entera sigue navegando al detalle al tap (el botón es hijo —
  su toque no propaga al InkWell de la card).

### 2. Detalle del pedido — hija `/admin/orders/:id`

Mismo patrón del detalle de cliente (§023/§027): `GoRoute(path: ':id')`
hija de la rama `/admin`, `redirect` sin `extra` → `/admin`,
`CustomTransitions.slideUp`, `extra` = `AdminOrder`,
`BlocProvider.value(locator<AdminQueueCubit>())` — el detalle opera
sobre el MISMO cubit de la cola: volver atrás muestra la cola ya
actualizada (y el back de hija ya funciona por el fix §031b).

Contenido (misma familia visual straddle + zona negra):

- **Header**: chips canal + estado, "hace N min", cliente (nombre o
  "En el local · Mesa N"), `#id` corto.
- **Ítems COMPLETOS** — la lista entera (los 7 ítems de Mesa 5 se ven
  todos acá: cantidad × nombre, uno por fila) + total.
- **Pago**: método + estado + botón **"Me pagó"** visible solo cuando
  `payment == pending` (cash en la entrega o transferencia llegada por
  fuera — el dueño confirma que la plata entró).
- **Acciones** (bloque inferior):
  - Botón primario de avance — misma matriz del punto 1.
  - `Listo` queda **deshabilitado con pista** ("Marca el pago primero")
    cuando el pago sigue pendiente — adelanta la regla del backend en
    vez de dejar que falle.
  - **"Cancelar pedido"** (text-button color error) → diálogo de
    confirmación con campo opcional de motivo (`cancelReason` ya lo
    acepta el backend). Confirmado → mock cancela + toast + pop a la
    cola (la orden ya no existe para mirarla).
- Tras `done` el detalle se queda abierto mostrando el estado terminal
  (las acciones se repliegan, chip Listo) — el dueño entrega el pedido
  y ve la confirmación; back vuelve a la cola ya sin la card en
  activos.

### 3. Cubit — métodos mock de operación

`AdminQueueCubit` gana (todos con la latencia mock ~400ms y busy por
pedido — `busyOrderIds` en el state para los spinners inline):

- `advanceOrder(id)` — aplica la matriz: pending→confirmed,
  confirmed/preparing→done; done/cancelled → no-op.
- `markPaid(id)` — paymentStatus pending→paid (la "me pagó").
- `cancelOrder(id, {reason})` — → cancelled.
- Los terminales se mueven de `active` a `history` al resolverse —
  `visible` ya ordena cada bucket (por-confirmar FIFO / recientes).
- El detalle lee la orden viva del state (por id) — tras cada acción
  ve el estado nuevo sin re-navegar.

### 4. Mock de semilla (sin cambios)

Conserva la matriz actual (incluido Beto Dos en `preparing` — ejercita
el chip y la rama del botón aunque el contrato no lo emita; queda
documentado). La Mesa 5 de 7 ítems es el caso que el detalle resuelve.

## Archivos

| Archivo | Cambio |
|---------|--------|
| `lib/features/admin/presentation/widgets/admin_order_card.dart` | Fila de acción (FilledButton por matriz estado×pago + spinner busy) |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | `advanceOrder`/`markPaid`/`cancelOrder` + swaps mock de bucket |
| `lib/features/admin/presentation/cubit/admin_queue_state.dart` | `busyOrderIds` + lookup por id para el detalle |
| `lib/features/admin/presentation/screens/admin_order_detail_screen.dart` | Pantalla detalle (nueva) |
| `lib/features/admin/presentation/widgets/` | header detalle, lista ítems completa, fila pago, bloque acciones, diálogo cancelar (extraídos por file-size) |
| `lib/core/routes/app_router.dart` | Hija `:id` de `/admin` (extra + redirect + slideUp + BlocProvider.value) |
| `lib/l10n/app_es.arb` | Confirmar / Me pagó / Listo / cancelar+motivo / pista "marca el pago" / título detalle / toasts |
| tests | matriz de labels, taps que mutan el mock, done→historial, detalle con 7 ítems + acciones, diálogo cancelar, redirect sin extra |
| `Design/design-system.yaml` | bump + spec del botón de acción en card + spec del detalle |

## Fuera de alcance

- Integración real (`PATCH status`, `POST confirm-payment`) — ciclo 2b
  tras la aprobación visual.
- Form "Nueva orden" presencial — ciclo 3.
- Notificaciones al cliente por cambio de estado — el backend aún no
  tiene ese módulo.

## Verificación

- `flutter analyze` + suite completa.
- Tests: labels de la matriz (pending→Confirmar; confirmed+pendiente→
  "Me pagó"; confirmed+pagado→"Listo"); tap muta el estado mock;
  done/cancelled salen de activos; detalle muestra los 7 ítems;
  "Listo" deshabilitado con pista si falta pago; cancelar exige
  confirmación; `/admin/orders/x` sin extra → `/admin`.
- Emulador: avanzar Ana Uno (Confirmar), cobrar Mesa 3 (Me pagó),
  completar un pedido (Listo → desaparece de activos y aparece en
  Historial), cancelar con motivo. revisor-estetico + revisor-ui sobre
  capturas de ambas superficies.
- Commit solo tras aprobación visual del usuario.
