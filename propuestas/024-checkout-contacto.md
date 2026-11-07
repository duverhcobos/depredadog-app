# Propuesta: Checkout — celular de quien recibe (contact_phone del pedido)

Requerimiento nuevo del usuario: **al hacer un pedido hay que guardar el
número de quién recibe**. El dueño entrega personalmente — si llega a la
referencia y nadie sale, necesita a quién llamar. Quien recibe puede NO
ser el titular de la cuenta ("Casa de mi mamá" → el celular de ella).

**Decisiones ya tomadas con el usuario (encuesta previa a esta
propuesta):**

1. **Un solo número nuevo: quién recibe.** El "quién paga" ya está
   cubierto — en Nequi es `nequiPhone` del checkout (viaja a
   `payments`); en efectivo contra entrega quien recibe = quien paga.
   No hay segundo campo.
2. **Vive en el pedido**, no en la dirección guardada — campo por
   pedido en el checkout, prellenado con el celular de la cuenta
   (`authSession.currentUser?.phone`, mismo origen que `nequiPhone`),
   editable.
3. **Solo domicilio.** Obligatorio ahí; en modo Local ni se muestra
   (quien recoge se identifica en el mostrador). En backend la columna
   es nullable — pickup y presencial pueden quedar NULL.

**Cambio de modelo (backend, documentado — la migración llega en la
propuesta 015 de endpoints):**

- `orders.contact_phone varchar(20)` NULL — quién recibe el pedido.
- `payments.payer_phone varchar(20)` NULL — celular que recibe el push
  Nequi (quién paga); NULL en `cash`.
- `documentacion/modelo-de-datos.md` se actualiza en esta propuesta
  (skill `modelo-evolucion`: el doc registra la decisión ya tomada).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/checkout/presentation/cubit/checkout_state.dart` | `+contactPhone`, `+showContactPhoneError` |
| `lib/features/checkout/presentation/cubit/checkout_cubit.dart` | prefill + `contactPhoneChanged` + validación en `confirm` |
| `lib/features/checkout/presentation/widgets/delivery_address_block.dart` | 3ª división: campo "Celular de quien recibe" + foco-al-error |
| `lib/features/orders/domain/entities/customer_order.dart` | `+contactPhone` |
| `lib/features/orders/presentation/cubit/orders_cubit.dart` | mocks delivery con `contactPhone` |
| `lib/features/orders/presentation/screens/order_detail_screen.dart` | línea "Recibe" en sección entrega |
| `lib/l10n/app_es.arb` | +3 keys |
| `pcalientes_backend/documentacion/modelo-de-datos.md` | +2 columnas documentadas (modelo-evolucion) |
| `test/features/checkout/…` `test/features/orders/…` | tests del campo/validación/visibilidad |
| `Design/design-system.yaml` | bump patch + spec actualizada |

---

## 1. CheckoutState

```dart
const CheckoutState({
  // … existentes
  this.contactPhone = '',
  this.showContactPhoneError = false,
});

/// Celular de quién RECIBE el pedido (§024 — requerimiento del
/// usuario). Solo aplica a domicilio: el repartidor lo llama si no
/// encuentra la casa o nadie sale. Prefill del `phone` de la cuenta;
/// editable porque quien recibe puede ser otra persona.
/// Quien PAGA ya está cubierto: Nequi → [nequiPhone]; efectivo →
/// quien recibe paga al recibir.
final String contactPhone;

/// Error inline tras confirm inválido: en domicilio el celular de
/// contacto es requerido y debe ser celular colombiano.
final bool showContactPhoneError;
```

`copyWith` + `props` actualizados.

## 2. CheckoutCubit

```dart
// constructor — mismo prefill que nequiPhone:
contactPhone: authSession.currentUser?.phone ?? '',

void contactPhoneChanged(String value) =>
    emit(state.copyWith(contactPhone: value, showContactPhoneError: false));
```

En `confirm()` — tercera regla (misma `_colombianMobile`):

```dart
final contactOk = state.orderType == CheckoutOrderType.pickup ||
    _colombianMobile.hasMatch(state.contactPhone.trim());
// …en el emit inválido: showContactPhoneError: !contactOk
```

## 3. DeliveryAddressBlock — división del contacto

Tercera división del bloque, **después** del pin (hairline + padding
mismo patrón §022d): "dónde entrego" → "a quién llamo".

```dart
Divider(height: 1, indent: 14, endIndent: 14, …),
const _ContactPhoneField(),
```

```dart
/// Celular de quién recibe el pedido (§024 — solo domicilio).
/// Espejo del campo Nequi (payment_block): CustomTextField +
/// keyboardType.phone + digitsOnly + LengthLimiting(10) +
/// AutofillHints.telephoneNumber. NO usa PhoneInput Formz — ese es el
/// idioma del registro; el checkout valida plano en el cubit.
class _ContactPhoneField extends StatefulWidget { … }
```

- `TextEditingController` sembrado desde `state.contactPhone` en
  `initState` (el bloque se desmonta al alternar tipo — mismo patrón
  del landmark, líneas 47-51).
- Label: `checkoutContactPhoneLabel` = "Celular de quien recibe".
  Hint: `checkoutContactPhoneHint` = "3XX XXX XXXX". Error:
  `checkoutContactPhoneRequired` = "Necesitamos el celular de quien
  recibe el pedido".
- `BlocListener` existente se extiende (o segundo listener):
  `showContactPhoneError` false→true → `_contactFocus.requestFocus()`
  **solo si** el landmark no ganó el foco antes (mismo patrón: el
  listener de address corre primero; si ya enfocó landmark no peleamos
  — implementación: en el mismo listener, foco al primer inválido en
  orden de pantalla: landmark → contacto).

## 4. Orders — entidad + mocks + detalle

`CustomerOrder`:

```dart
/// Celular de quién recibe (§024) — solo pedidos delivery.
final String? contactPhone;
```

Mocks: ord-1 → '3001234567', ord-6 → '3109876543' (otra persona — se
ve que no es el de la cuenta). Pickups NULL.

`order_detail_screen` — sección entrega (delivery): tras la línea de
dirección/referencia, nueva línea ícono `Icons.phone_rounded`:

```
Recibe: 300 123 4567    →  l10n.orderContactPhone({phone})
```

Formato de display `3XX XXX XXXX` (máscara simple en el formatter del
feature o inline — ya existe el patrón del registro; revisar si hay
helper antes de duplicar).

## 5. l10n (+3)

- `checkoutContactPhoneLabel` — "Celular de quien recibe"
- `checkoutContactPhoneHint` — "3XX XXX XXXX"
- `checkoutContactPhoneRequired` — "Necesitamos el celular de quien recibe el pedido"
- `orderContactPhone` — "Recibe: {phone}" (con placeholder)

## 6. Backend — modelo-de-datos.md

Tabla `orders`: +fila `contact_phone varchar(20) NULL — quién recibe;
app lo exige en delivery (§024)`. Tabla `payments`: +fila
`payer_phone varchar(20) NULL — celular Nequi que recibe el push
(transfer); NULL en cash`. Decisiones tomadas (`orders`): +línea de la
decisión. **Sin migración todavía** — viaja con la propuesta 015
(ALTER TABLE orders + payments).

## 7. Tests

- `checkout_cubit_test`: confirm en delivery con `contactPhone` vacío/
  inválido → `showContactPhoneError` true + no confirma; en pickup el
  flag no aplica; `contactPhoneChanged` limpia el flag.
- `checkout_screen_test`: el campo no existe en Local; aparece en
  Domicilio prellenado con el celular del usuario mock; error inline
  tras confirm inválido.
- `orders_screen_test` (detalle): pedido delivery muestra "Recibe: …";
  pickup no muestra la línea.
- Ajustar confirm-tests existentes: ahora delivery válido exige
  también `contactPhone` — los casos felices ya traen prefill, solo
  revisar que ninguno lo limpie.

## 8. design-system.yaml

Bump `1.30.0` → `1.30.1` (patch — una división más de la familia, sin
componente nuevo). Spec `checkout` + `orders` se actualizan; changelog.

---

## Criterios de aceptación

- En **Domicilio** aparece "Celular de quien recibe" prellenado con el
  celular de la cuenta, editable, con su propia división al pie del
  bloque de entrega.
- En **Local** el campo no existe en el árbol.
- Confirm en domicilio con el campo vacío o no-celular → error inline
  rojo + foco (y NO confirma); en local esa regla no corre.
- Detalle de pedido delivery muestra "Recibe: 3XX…" con ícono teléfono;
  pickup no la muestra.
- Modelo backend documentado (`contact_phone`, `payer_phone`) — la
  migración física queda para la propuesta 015.
- `flutter analyze` limpio + suite completa verde + aprobación visual.
