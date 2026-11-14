# Propuesta: Detalle de pedido admin completo (§037)

El detalle admin hoy solo muestra chips + cliente + ítems planos + método de pago.
El dueño que prepara, cobra y entrega necesita: **a dónde lleva el domicilio, a
quién llama, cómo va armado cada perro, el desglose del cobro y las
observaciones del cliente**. Se reutilizan las piezas del detalle del cliente
(§023/§024): `OrderItemDetailPanel`, `formatPhone`, claves arb existentes.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/admin/domain/entities/admin_order.dart` | Nuevos campos de detalle; `total` pasa a getter `subtotal + deliveryFee` |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | Mocks: `total:` → `subtotal:`/`deliveryFee:`; datos de entrega/nota en domicilios; modificadores en ítems |
| `lib/features/admin/presentation/widgets/order_detail/admin_order_delivery_section.dart` | **Nuevo** — sección "Entrega" (dirección/referencia/barrio/pin/teléfono o línea de recogida) |
| `lib/features/admin/presentation/widgets/order_detail/admin_order_detail_items.dart` | Reescrito — ítems expandibles con `OrderItemDetailPanel` + desglose subtotal/domicilio/total |
| `lib/features/admin/presentation/widgets/order_detail/admin_order_note_section.dart` | **Nuevo** — sección "Observación" |
| `lib/features/admin/presentation/screens/admin_order_detail_screen.dart` | Inserta las dos secciones nuevas en el ListView |
| `lib/l10n/app_es.arb` (+ `app_en.arb`) | Claves nuevas de sección/teléfono |
| `test/features/admin/...` | Tests del detalle enriquecido + actualizar helpers que construyen `AdminOrder` con `total:` |

---

## 1. Entidad — `admin_order.dart` (existente, actualización)

**Antes:**

```dart
  const AdminOrder({
    required this.id,
    required this.channel,
    required this.serviceType,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.placedAt,
    this.tableLabel,
    this.customerName,
    this.cancelReason,
  });
  // ...
  /// Total cobrado (subtotal + deliveryFee — el DTO ya lo trae
  /// compuesto).
  final int total;
  final DateTime placedAt;
```

**Después:**

```dart
  const AdminOrder({
    required this.id,
    required this.channel,
    required this.serviceType,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.placedAt,
    this.tableLabel,
    this.customerName,
    this.cancelReason,
    this.addressLabel,
    this.landmark,
    this.neighborhood,
    this.hasLocationPin = false,
    this.contactPhone,
    this.note,
  });
  // ...
  /// Subtotal de ítems y domicilio — el DTO los trae separados
  /// (OrderResponse del backend §015). El desglose los muestra.
  final int subtotal;
  final int deliveryFee;

  /// Total cobrado = subtotal + domicilio (misma regla del
  /// CustomerOrder).
  int get total => subtotal + deliveryFee;
  final DateTime placedAt;
```

Campos nuevos (mismos nombres/semántica del `CustomerOrder` — el DTO
admin los espeja 1:1):

```dart
  /// Bloque de entrega (solo delivery — null en pickup/dineIn):
  /// etiqueta de la dirección ("Casa"), punto de referencia (la zona
  /// no tiene direcciones formales), barrio, pin de Maps adjunto y
  /// celular de quién recibe (§024).
  final String? addressLabel;
  final String? landmark;
  final String? neighborhood;
  final bool hasLocationPin;
  final String? contactPhone;

  /// Observación libre del cliente ("sin picante, es para el niño").
  final String? note;
```

`copyWith` y `props`: agregar los campos nuevos (`subtotal`, `deliveryFee`,
`addressLabel`, `landmark`, `neighborhood`, `hasLocationPin`, `contactPhone`,
`note`; quitar `total` de props y del constructor de copyWith).

Actualizar el docstring de la clase (quita la línea "orderNumber,
contactPhone, deliveryAddress, discount y notes llegan cuando el detalle
se integre" — ya llegaron).

## 2. Mocks — `admin_queue_cubit.dart` (existente, actualización)

**Mecánico (todas las ~30 órdenes):** `total: N` → `subtotal: N,
deliveryFee: 0`. En las de **delivery** el fee es > 0:
`total: 56000` → `subtotal: 51000, deliveryFee: 5000` (misma plata, el
fee sale del total anterior — elegir fees de $3.000–$5.000).

**Datos de entrega en los domicilios** (los online delivery + Óscar
presencial por teléfono): `addressLabel`, `landmark`, `neighborhood`,
`hasLocationPin` (alternar true/false), `contactPhone` ("3001234567" —
números de prueba distintos). Ejemplo adm-1:

```dart
      AdminOrder(
        id: 'adm-1',
        // ...igual hasta paymentStatus...
        subtotal: 51000,
        deliveryFee: 5000,
        placedAt: now.subtract(const Duration(minutes: 12)),
        customerName: 'Ana Uno',
        addressLabel: 'Casa',
        landmark: 'Portón negro frente a la cancha',
        neighborhood: 'Barrio La Esperanza',
        hasLocationPin: true,
        contactPhone: '3001234567',
        note: 'Sin picante — es para el niño',
      ),
```

**Nota (`note`)** también en 1 pickup ("La recoge mi hermano") y 1 mesa
("Uno sin cebolla porfa").

**Personalización en ítems** — sembrar `modifiers`/`includedNames` en
varios pedidos para que el panel tenga contenido (los `priceDelta` son
informativos: `unitPrice` ya viene compuesto — no cambian los totales):

```dart
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 2,
            unitPrice: 25000,
            includedNames: const [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: const [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
              ),
              CartModifier(
                optionId: 'ex-queso',
                optionName: 'Queso cheddar',
                action: CartModifierAction.added,
                group: CartModifierGroup.extra,
                priceDelta: 2500,
              ),
              CartModifier(
                optionId: 'sa-pina',
                optionName: 'Piña',
                action: CartModifierAction.added,
                group: CartModifierGroup.sauce,
              ),
            ],
          ),
```

Sembrar al menos: adm-1 (delivery con todo), adm-7/Mesa 5 (varios ítems
con modificadores — la orden grande), un Nequi congelado y un
presencial. Importar `cart_modifier.dart` en el cubit.

## 3. `admin_order_delivery_section.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/widgets/order_detail/admin_order_delivery_section.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../../orders/presentation/utils/format_phone.dart';
import '../../../domain/entities/admin_order.dart';
import '../../../../core/presentation/widgets/app_toast.dart';

/// Sección "Entrega" del detalle admin (§037) — lo que el dueño
/// necesita para sacar el domicilio: etiqueta + punto de referencia +
/// barrio + pin de Maps y el celular de quién recibe (tocar la fila
/// copia el número — la zona no siempre tiene dirección formal, el
/// teléfono es el plan B). Pickup solo dice "lo recogen en el local"
/// (+ referencia del local si el pedido trae una). dineIn no
/// renderiza — la mesa ya sale en el header.
class AdminOrderDeliverySection extends StatelessWidget {
  const AdminOrderDeliverySection({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.serviceType == AdminServiceType.dineIn) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final isDelivery = order.serviceType == AdminServiceType.delivery;
    return CustomizationSection(
      title: l10n.adminOrderDetailDeliverySection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDelivery) ...[
                if (order.addressLabel != null)
                  Text(order.addressLabel!, style: text.bodyMedium),
                if (order.landmark != null)
                  Text(
                    order.landmark!,
                    style: text.bodyMedium?.copyWith(color: muted),
                  ),
                if (order.neighborhood != null)
                  Text(
                    order.neighborhood!,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                if (order.hasLocationPin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.orderWithLocationPin,
                          style: text.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                // §024 — a quién llamar si nadie sale. Tap copia.
                if (order.contactPhone != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _PhoneRow(
                      phone: order.contactPhone!,
                      onCopy: () async {
                        await Clipboard.setData(
                          ClipboardData(text: order.contactPhone!),
                        );
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            l10n.adminOrderPhoneCopied,
                          );
                        }
                      },
                    ),
                  ),
              ] else
                Text(
                  // "Lo recogen en el local" (vista dueño) o la
                  // referencia del local si el pedido trae una.
                  l10n.adminOrderPickupAtStore,
                  style: text.bodyMedium?.copyWith(color: muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone, required this.onCopy});

  final String phone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.phone_rounded, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.orderContactPhone(formatPhone(phone)),
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 15,
              color: colors.primary.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 4. `admin_order_detail_items.dart` (existente — reescritura)

**Ruta:** `lib/features/admin/presentation/widgets/order_detail/admin_order_detail_items.dart`

Mismo archivo, dos cambios:

- `_ItemRow` → `_ItemLine` **StatefulWidget** — la fila se vuelve
  expandible con `OrderItemDetailPanel(item:)` bajo `AnimatedSize`
  180ms, mismo patrón de `_ItemLine`/`_ItemLineState` de
  `order_detail_screen.dart` (líneas 252-371). **Diferencia de
  cocina (decisión del usuario):**
  - El chip "Detalle" solo existe cuando el ítem TIENE algo que ver
    (`modifiers.isNotEmpty || includedNames.isNotEmpty`) — un perro
    estándar no gasta un chip que abre a "Así como viene".
  - **Auto-expandido de nacimiento cuando `modifiers.isNotEmpty`** —
    "sin cebolla" es instrucción de cocina y no puede depender de que
    el dueño toque; el ítem con solo `includedNames` (perro estándar
    con snapshot) nace colapsado y el chip lo abre.
  - `_ItemLine` recibe `item` y define `_expanded` inicial con esa
    regla; semántica `cartItemDetailToggle` solo cuando hay chip.
- El cierre ya no es solo "Total": **desglose** igual al `_Totals` del
  cliente — fila Subtotal, fila Domicilio solo si `serviceType ==
  AdminServiceType.delivery` ("Gratis" primary cuando fee==0), fila
  Total primary. Regla del cancelado (total apagado) se conserva en la
  fila Total.

Importar `order_item_detail_panel.dart` y `app_localizations` keys
`orderSummarySubtotal`/`orderSummaryDelivery`/`orderSummaryFree`/
`orderSummaryTotal`/`cartItemDetail`/`cartItemDetailToggle`.

## 5. `admin_order_note_section.dart` (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/widgets/order_detail/admin_order_note_section.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../domain/entities/admin_order.dart';

/// Observación del cliente (§037) — sección propia para que la nota
/// no se pierda entre ítems y pago: "sin picante, es para el niño" es
/// instrucción de cocina. No renderiza sin nota.
class AdminOrderNoteSection extends StatelessWidget {
  const AdminOrderNoteSection({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final note = order.note;
    if (note == null || note.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return CustomizationSection(
      title: l10n.orderDetailNoteSection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(note, style: text.bodyMedium),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

## 6. `admin_order_detail_screen.dart` (existente — actualización)

**Antes:**

```dart
        children: [
          const _DetailTitle(),
          AdminOrderDetailHeader(order: resolved),
          AdminOrderDetailItems(order: resolved),
          AdminOrderDetailPayment(order: resolved, busy: busy),
        ],
```

**Después** — la Observación va justo bajo el Pedido (decisión del
usuario: "sin picante, es para el niño" se lee antes que los ítems —
abajo se pierde):

```dart
        children: [
          const _DetailTitle(),
          AdminOrderDetailHeader(order: resolved),
          AdminOrderNoteSection(order: resolved),
          AdminOrderDeliverySection(order: resolved),
          AdminOrderDetailItems(order: resolved),
          AdminOrderDetailPayment(order: resolved, busy: busy),
        ],
```

+ imports de los dos widgets nuevos.

## 7. i18n — `lib/l10n/app_es.arb` (+ `app_en.arb`)

```arb
"adminOrderDetailDeliverySection": "Entrega",
"adminOrderPickupAtStore": "Lo recogen en el local",
"adminOrderPhoneCopied": "Teléfono copiado",
```
(EN: "Delivery", "They pick it up at the store", "Phone copied")

Reutilizadas del cliente (sin cambios): `orderDetailNoteSection`,
`orderContactPhone`, `orderWithLocationPin`, `orderSummarySubtotal`,
`orderSummaryDelivery`, `orderSummaryFree`, `orderSummaryTotal`,
`cartItemDetail`, `cartItemDetailToggle`. Ejecutar `flutter gen-l10n`.

## 8. Tests

- `test/features/admin/admin_order_detail_test.dart` (o donde viva el
  detalle): helpers que construyen `AdminOrder` con `total:` →
  `subtotal:`/`deliveryFee:`.
- Casos nuevos: domicilio muestra etiqueta+referencia+barrio+pin+
  teléfono; pickup muestra "Lo recogen en el local"; dineIn no muestra
  la sección; tap en ítem despliega el panel con "Cebolla" en quitados
  y "+$2.500" del extra; desglose muestra subtotal+domicilio+total;
  nota visible / sección ausente sin nota.
- Cualquier test que lea `order.total` sigue funcionando (getter).

---

---

## Decisiones (encuesta previa — recomendaciones aceptadas)

- **Sección Entrega**: domicilio (completa) + recogida (una línea);
  mesa NO la muestra — la mesa ya sale en el header.
- **Ítems**: chip "Detalle" solo cuando hay algo que ver; los ítems
  CON modificadores nacen expandidos (la cocina no puede depender de
  que el dueño toque para ver "sin cebolla").
- **Teléfono**: tap copia al portapapeles + toast (sin url_launcher).
- **Observación**: justo bajo la sección Pedido — instrucción de
  cocina, va antes que los ítems.

---

## Orden de aplicación

1. `admin_order.dart` (entidad + copyWith + props)
2. `admin_queue_cubit.dart` (mocks — mecánico subtotal/fee + datos de
   entrega + modificadores)
3. `app_es.arb`/`app_en.arb` + `flutter gen-l10n`
4. `admin_order_delivery_section.dart` (nuevo)
5. `admin_order_note_section.dart` (nuevo)
6. `admin_order_detail_items.dart` (reescritura)
7. `admin_order_detail_screen.dart` (insertar secciones)
8. Tests + `flutter analyze` + `flutter test`
9. Rebuild al emulador → gate visual del usuario → design-system yaml

## Ajuste post-revisión del dueño (continuación)

- **Pin de Maps accionable**: la fila "Con ubicación de Google" deja de ser
  texto inerte — `AdminOrder` gana `locationLat`/`locationLng` (espejo
  `addresses.latitude/longitude` del backend; mocks sembrados en los 6
  domicilios con pin). Con coordenadas: **tap abre Google Maps** con el
  punto (`url_launcher`, `LaunchMode.externalApplication`) y el ícono de
  copiar clona el enlace `maps/search/?api=1&query=lat,lng` al portapapeles
  + toast "Ubicación copiada". Sin coordenadas (DTO viejo) queda
  informativo como antes. Decisión del dueño: "tap y copiar también".
- Dependencia nueva: `url_launcher ^6.3.3`.
- **locationUrl canónico**: `AdminOrder.locationUrl` — el enlace
  compartido real (maps.app.goo.gl/…) que el cliente guardó al fijar
  el pin. Si existe se abre y se copia verbatim; lat/lng queda como
  fallback para reconstruir la query. Decisión del dueño: "utiliza
  esa url" → mocks sembrados con maps.app.goo.gl/s5RiFni6LsV4Ptmj9.
  Fix manifest: <queries> VIEW/https — sin ella Android 11+ bloqueaba
  launchUrl() en silencio (package visibility).
- **Identificador visible**: el formato `#adm-N` queda APROBADO como
  formato definitivo — el dueño es el único espectador del detalle
  admin, no hace falta correlativo ni UUID largo. Al integrar el
  backend (022) se mantiene el formato corto (p.ej. `#adm-<n>` o
  prefijo corto del UUID real), sin columna order_no ni UUID completo.
