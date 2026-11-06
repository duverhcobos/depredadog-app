# Propuesta: Checkout — confirmación del pedido (§022, solo presentación)

Siguiente pantalla del flujo de compra (screen-first): al tocar "Ir a pagar" en
el carrito se abre la pantalla donde el cliente define **cómo recibe** (recoger
en el local / domicilio), **cómo paga** (Nequi / al recibir), deja una **nota**
y revisa el **resumen con totales** antes de confirmar.

Solo presentación: datos de prueba (direcciones guardadas, store config),
estado local, sin endpoints. La integración llega por endpoint: `GET
/store/config` (ya existe en backend 013 — alimenta dirección del local, fee,
mínimo y el pill "Abierto" mock), `addresses` (backend 014) y `POST /orders`
(backend 015).

## Ruta y estado

- `AuthGuard.checkoutRoute = '/home/cart/checkout'` — hija de `cart`
  (slideUp, conserva shell + nav). El CTA "Ir a pagar" deja el toast y hace
  `context.push`. Sin ítems → redirect a `/home/cart` (deep link directo con
  carrito vacío no tiene sentido).
- `CheckoutCubit` (nuevo, `factory` por apertura — estado de pantalla, no
  compartido): `orderType` (pickup/delivery), `addressId` seleccionado (o
  `newAddress` con sus campos), `paymentMethod` (nequi/onDelivery),
  `nequiPhone` (prefill del celular de la cuenta, editable), `note`,
  `confirmInProgress`. Lee `CartCubit` para ítems/subtotal — NO lo modifica
  (la confirmación real vaciará el carrito en §015).

## Pantalla (familia straddle + scrolling_title "Confirmar pedido")

Cards `straddle_card` (misma geometría del carrito/detalle), una por sección:

1. **Tipo de pedido** — toggle segmentado propio (2 píldoras radius pill en
   track surfaceContainerHighest; activa = primary con onPrimary, decisión
   visual consistente con SelectChip lleno):
   - "Recoger en el local" → línea "Lo recoges en" + dirección mock del local
     + "Te avisamos cuando esté listo".
   - "Domicilio" → chips de direcciones guardadas mock (`Casa` — Calle 45
     #12-34, `Trabajo` — Cra 10 #5-67) + opción "Nueva dirección" que despliega
     el form inline (AnimatedSize): `Dirección *` (calle), `Barrio *`,
     `Referencia / indicaciones` (opcional) + checkbox "Guardar esta
     dirección". Validación al confirmar: domicilio exige selección o form
     completo.
2. **Pago** — radio rows (mismo idioma que OptionRow del detalle):
   - "Nequi" + subtítulo "Te llega la notificación push" + **campo de
     celular prellenado con el de la cuenta y editable** (decisión del
     usuario — el push puede ir a otra cuenta Nequi distinta). El prefill
     viene de `AuthSession.user.phone` — es opcional en el registro, así
     que si viene null el campo arranca vacío. Requerido si Nequi está
     seleccionado: vacío o formato inválido → error genérico al
     confirmar. Formato solo dígitos máx 10 (mismo filtro del teléfono
     del registro).
   - "Pagar al recibir" (pickup) / "Pagar al recibir tu pedido" (domicilio) —
     label dinámico por tipo.
3. **Nota para el local** — TextField multiline opcional
   ("¿Algo que debamos saber? — p. ej. timbre no sirve") — el modelo de orden
   tiene la nota a nivel pedido (§013), no por ítem.
4. **Tu pedido** — resumen compacto: una línea por ítem
   `N× Nombre` … `lineTotal` (sin modificadores — ya se auditaron en el
   carrito) + hairline + `Subtotal`, `Domicilio` (fee mock $2.000 solo en
   delivery; en pickup la fila no se muestra), `TOTAL` en Anton primary w800.
   - **Sin mínimo de domicilio** (decisión del usuario): la app no
     valida monto mínimo — el fee es fijo si el negocio decide cobrarlo
     y punto. Nada de aviso ni bloqueo por subtotal bajo.
5. **Footer fijo** (idéntico al carrito/detalle): `Total` + valor + CTA
   `Confirmar pedido`.

## Confirmación (decisión embebida — flujo completo simulado)

Tap en Confirmar → delay mock 800ms (IgnorePointer + spinner en el botón) →
`AlertDialog` de éxito: ícono check_circle primary, "¡Pedido confirmado!",
"#15 · Te avisamos cuando esté listo" (número mock — el consecutivo real es
del backend) + CTA "Ver mis pedidos" → cierra el diálogo, `CartCubit.clear()`
y `go(ordersRoute)` (placeholder hasta §023). Es el UX real de punta a punta
para evaluarlo — marcar PROVISIONAL en el spec.

## l10n (~20 claves)

Título, tipos de pedido, direcciones, labels de pago, nota, resumen,
totales, mínimo, confirmar, diálogo de éxito.

## Tests

Widget tests del cubit (selección/totales/validación: dirección requerida en
domicilio, celular Nequi requerido y válido) y de la pantalla (toggle cambia
la sección de dirección, pago dinámico por tipo, campo celular aparece solo
con Nequi y viene prellenado, form de nueva dirección, confirmación →
diálogo + clear + navegación con GoRouter mínimo).

## Design system

Spec `checkout` nuevo + componente `segmented_toggle` si aplica → 1.24.0.

## Fuera de alcance

Integración de endpoints, direcciones reales, Nequi real, persistencia,
pantalla de detalle del pedido creado (§023 pedidos).

## Anexo §022a — revisión del usuario en validación visual

Decidido por el usuario al ver el checkout en el emulador (post-revisores):

1. **La zona no tiene nomenclatura de calles** — las entregas se guían
   por puntos de referencia. El form pasa a: `Punto de referencia *`
   (único requerido) + `Barrio o sector (opcional)` + adjuntar
   ubicación de Google Maps (mock: botón → estado adjunto con link +
   Quitar) + `Guardar esta ubicación`. Se retiran `Dirección`,
   `Referencia` y el requerido de `Barrio`. `SavedAddress.street` →
   `landmark`; `neighborhood` opcional; mocks reescritos como
   referencias de vereda (incluido el store).
2. **Domicilio GRATIS** — debe especificarse: aviso `Domicilio gratis`
   con moped al inicio del bloque de entrega + fila del resumen muestra
   `Gratis` en primary cuando fee=0 (mock `deliveryFee` 2000→0).
3. **Logo real de Nequi** — SVG oficial (CC BY-SA 4.0, Wikimedia
   Commons; atribución en `assets/ATTRIBUTION.md`) sobre tile blanco
   30×30 (el wordmark #200020 es ilegible en tema oscuro — idioma de
   logos de pago). `CheckoutOptionRow` gana param `leading` (Widget) —
   marca sin teñir. Subtítulo `Te llega la notificación push` retirado.
4. **`Nota para el local` → `Observación`** y reubicada justo bajo
   `Tipo de pedido` (orden: tipo → observación → pago → resumen); hint
   con ejemplo acorde a la zona (`p. ej. pago con billete de 50,
   traer cambio`).
5. **CTA `Confirmar pedido` aprobado tal cual** (cierra la duda INFO
   del revisor-ui del eco título↔botón — queda como está).

## Anexo §022b — segunda revisión del usuario en validación visual

Decidido por el usuario tras ver §022a en el emulador (las dos opciones
de UX se presentaron con dibujo y eligió las recomendadas):

1. **`Recoger en el local` → `Local`** — label corto de la píldora
   del toggle (`checkoutPickupOption`).
2. **`Nueva ubicación` es TOGGLE** — tocar la fila ya seleccionada
   colapsa el form y restaura la última ubicación guardada elegida
   (`CheckoutCubit._lastAddressId` + `deselectNewAddress`). El mismo
   gesto que la abrió la cierra (patrón del chip `Detalle` del
   carrito); los campos tipeados sobreviven en el cubit — reabrir no
   pierde nada.
3. **Tipo de ubicación solo al guardar** — el nombre (`Casa`/
   `Trabajo`/`Otro`) solo sirve si la ubicación se va a guardar, así
   que el selector vive detrás del checkbox `Guardar esta ubicación`
   (AnimatedSize 180ms easeOutCubic — física de la familia): label
   `¿Qué lugar es?` + `SelectChip`s reusados del detalle. `Otro`
   revela `Nombre del lugar` (`Ej: casa de mi mamá`) — la lista de
   guardadas mostrará ese nombre tal cual. Estado nuevo:
   `CheckoutState.newAddressType` (default `home`) +
   `newAddressLabel`; cubit: `setNewAddressType` /
   `newAddressLabelChanged` (mock — sin persistencia).
4. **Diálogo de confirmación SIN número de orden** — el consecutivo
   (`#15`) revela cuánto ha vendido el negocio; no se expone al
   cliente. `checkoutConfirmedSubtitle` pasa a texto fijo
   `Te avisamos cuando esté listo`.
5. **Ícono de Nequi (isotipo)** — el usuario prefirió el ícono
   "cuadro + N" al wordmark completo. `assets/images/nequi_icon.svg`
   recorta las dos primeras formas del SVG oficial (misma licencia
   CC BY-SA 4.0 y atribución); se mantiene el tile blanco.
6. **Fix visual** — `Adjuntar ubicación de Google` quedaba pegado al
   input de Barrio: el `helperText: null` de ese `CustomTextField`
   había anulado la línea reservada; se restauró el default `' '`
   (mismo ritmo entre campos).

---

## §022c — Revisión: el local es PREPAGO (solo transferencia)

Decisión de negocio del usuario: **en el local NO se acepta pago contra
entrega**. Razón: si el cliente no aparece a recoger, el pedido ya quedó
preparado y nunca se cobró — plata perdida. En domicilio sí se conserva
"Pagar al recibir tu pedido" porque el dueño cobra en la mano de la
entrega.

### Cambios

1. **Pickup = solo Nequi/transferencia** — `CheckoutCubit.setOrderType`
   a `pickup` fuerza `paymentMethod = nequi`; si el usuario venía de
   domicilio con "al recibir" seleccionado, al volver a Local se
   restaura Nequi automáticamente.
2. **Defensa en el cubit** — `setPaymentMethod(onDelivery)` se ignora
   estando en `pickup`: la combinación inválida no puede existir en el
   estado aunque la UI nunca la ofrezca.
3. **PaymentBlock** — la fila contra entrega solo se renderiza en
   domicilio (AnimatedSize 180ms, física de la familia). En pickup se
   muestra la nota `En el local el pago es solo por transferencia` —
   informativa atenuada (`info_outline_rounded` 15px + bodySmall
   onSurface 0.6): explica la restricción sin competir con el highlight
   mostaza de "Domicilio gratis".
4. **l10n** — `+checkoutPickupTransferNote`; `checkoutPayOnPickup`
   retirada (el label dinámico muere — la opción ya no existe en
   pickup).

### Tests §022c

- Cubit: domicilio con `onDelivery` → `setOrderType(pickup)` fuerza
  `nequi`; el caso "celular no exigido" se movió a domicilio (la vía
  válida de `onDelivery`).
- Screen: en Local no existe fila de efectivo y la nota es visible;
  en domicilio la fila reaparece y la nota se va.

---

## §022d — Revisión: pin de Google del PEDIDO + toggle puro + limpieza

Decisiones del usuario sobre el bloque de domicilio:

1. **El pin de Google es del pedido, no de la dirección nueva** —
   `Adjuntar ubicación de Google` sale del form y baja a su propia
   división (hairline + fila) al pie del bloque de direcciones. Sirve
   para cualquier dirección marcada — nueva o guardada — porque el
   punto exacto lo usa el repartidor sin importar la referencia.
   Estado: `newLocationLink` → `deliveryLocationLink` (order-level);
   cubit: `attachDeliveryLocation` / `removeDeliveryLocation`.
   El modelo real será lat/lng (no el link) — el link se genera para
   que el repartidor abra Maps con navegación (decisión documentada
   para la integración).
2. **"Nueva ubicación" colapsa sin desmarcar** — el segundo tap solo
   colapsa el form; la opción queda marcada (antes restauraba la
   última guardada). Desmarcar ahora es exclusivamente tocar otra
   dirección. `CheckoutState.newAddressExpanded` gobierna la
   visibilidad; un `confirm` fallido con el form colapsado e
   incompleto lo reabre para que el error inline sea visible.
   `_lastAddressId`/`deselectNewAddress` quedan muertos.
3. **Adiós al aviso "Domicilio gratis"** — la fila informativa sobre
   las direcciones sobraba: el "Gratis" del resumen ya lo dice donde
   importa (en la plata). `checkoutDeliveryFreeNotice` retirada.

### Tests §022d

- Cubit: toggle puro (colapsa marcada / reabre / desmarca solo con
  otra fila), pin order-level que sobrevive cambio de dirección,
  confirm reabre form colapsado con error.
- Screen: pin disponible con guardada marcada (fuera del form), aviso
  gratis ausente, segundo tap conserva selección, tercer tap reabre
  con datos.
