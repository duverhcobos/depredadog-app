# Pendiente: Nueva orden presencial (form del FAB de Cocina)

> **Estado: 🔴 PENDIENTE** — detectado en evaluacion-modulo de admin/Cocina
> **Producto:** app
> **Bloqueo:** bloqueante para operación presencial desde la app —
> hoy el dueño no puede tomar pedidos de mostrador/mesa/teléfono
> desde la app; el FAB visible dead-endea en un toast.

## Contexto

El FAB "+" de Cocina (`admin_queue_screen.dart`) muestra
"Disponible próximamente" — era el placeholder aceptado del mock.
Con el módulo ya 100% integrado, es la única acción visible en la
UI que no hace nada real. El backend ya tiene `POST /admin/orders`
(documentacion/api/admin/004-post-admin-orders.md) — el mismo que
se ha usado por curl en las verificaciones: acepta serviceType
(dineIn con tableId / pickup / delivery), ítems con modifiers,
paymentMethod y nota, y nace en `confirmed` para dineIn/delivery
presencial o `received` para pickup presencial.

## Qué falta

- Formulario de nueva orden presencial: selección de canal de
  servicio (mesa con picker de mesas libres — `GET /admin/tables`
  ya existe y marca disponibilidad — / mostrador / domicilio
  presencial), ítems con el mismo flujo de personalización del
  catálogo, método de pago y nota opcional.
- Nace como `confirmed` o `received` según la matriz del backend —
  cae directo a la cola kanban sin paso intermedio.
- Decidir el punto de entrada visual: form completo vs flujo tipo
  "comanda rápida" (iterar con el dueño — la operación real del
  local manda).

## Criterio de cierre

- El FAB abre el form real; un pedido presencial creado desde la
  app aparece en el carril correcto con la animación del diff.
- Tests del form + `flutter analyze`/`flutter test` verdes;
  verificación manual en el emulador.
