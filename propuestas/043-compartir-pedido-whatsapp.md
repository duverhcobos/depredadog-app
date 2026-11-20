# Propuesta 043 — Compartir pedido a WhatsApp (cocina)

> Estado: **implementada — en gate visual** (formato v2: imagen por
> ítem, decisión del dueño en gate).
> Feature: admin / nueva orden presencial + detalle de pedido.
> Sprint: app 043 (post-§042).

## Contexto y decisión del dueño

El dueño toma el pedido en la app y lo reenvía **al WhatsApp de
cocina** — los cocineros leen la comanda desde ese chat (no usan la
app). Decisiones tomadas en el gate visual:

1. **Formato**: **una imagen-card por ítem** — "opción A pero sin la
   imagen del perro" (v2; la V1 de texto `wa.me` quedó descartada
   porque "no me gustó el texto formateado").
2. **Disparador**: "Solo imagen" — el CTA "Enviar a cocina" lanza el
   share sheet con las cards (reemplaza el envío de texto).
3. **Ambos lugares**: tras crear la comanda Y desde el detalle.

Tradeoff aceptado: `wa.me` solo transporta texto — con imagen **no se
puede prellenar el número**: WhatsApp abre su pantalla de reenvío y
se elige el chat (cocina queda primero en recientes).

## Mecanismo

`share_plus` (nueva dependencia — estándar fluttercommunity,
`Share.shareXFiles`): render de una card-widget a PNG
(`RepaintBoundary` offscreen → `toImage(pixelRatio)`), un archivo
por ítem → share sheet → WhatsApp galería.

- Las PNG se escriben a `getTemporaryDirectory()` con nombre
  `pedido_<tag>_item_<n>.png`.
- Sin cambio de manifest: ACTION_SEND con chooser no exige queries.
- `canLaunch` no aplica — el chooser siempre resuelve; el toast de
  fallo (`adminShareWhatsAppFailed`) cubre exception de plataforma.

## La card (data + render)

Contenido por ítem (self-contained — cocina puede recibir solo una):

```
┌─────────────────────────────┐
│ DEPREDADOG · PEDIDO #5   1/2│  top: muted, item i de n
│ ─────────────────────────── │  hairline outlineVariant
│ 1× El Coyote                │  Anton primary, grande
│ − sin Chile con carne       │  removed: onSurface α.85
│ + Piña en trozos            │  added: ídem
│ salsas: Salsa de piña       │  group sauce en una línea
│                             │
│ Para llevar · Efectivo      │  footer muted
│ Nota: para la mesa del fondo│  solo si la nota no va vacía
│ Total: $14.000              │
└─────────────────────────────┘
```

- Fondo `surface` del tema, ancho fijo 600 logical px, padding 28,
  radius 24 con border `outlineVariant` fino — idioma card del sistema.
- Los datos salen del MISMO `KitchenOrderData`/`KitchenOrderLine` ya
  implementado (removed/added/sauces ya repartidos por tipo) — la
  card solo compone; `number`, `serviceLines.first`, `paymentMethod`,
  `placedAt` (hora), `note`, `total` cubren header+footer.
- Sin foto del producto (decisión explícita) ni precios por mod.

## Archivos

### Nuevos

- `lib/features/admin/presentation/widgets/kitchen_item_card.dart`
  — `KitchenItemCard` widget de render (la card de arriba, todo
  tokens del tema) + `renderKitchenItemCards(context, KitchenOrderData,
  l10n)` → `List<XFile>` (overlay offscreen + toImage + temp files).
  `shareKitchenItemCards(context, KitchenOrderData)` → orquesta
  render + `Share.shareXFiles` + toast de fallo.

### Modificados

- `kitchen_order_message.dart` — se conservan `KitchenOrderData`,
  `KitchenOrderLine` y los mappers (`fromCartItems`/`fromAdminOrder`);
  se retiran `buildKitchenOrderMessage` y `shareKitchenOrderWhatsApp`
  (el texto ya no se manda — V1 descartada) + su docstring; el
  archivo pasa a ser `kitchen_order_data.dart` (rename).
- `admin_new_order_screen.dart` — `_share` del success view llama a
  `shareKitchenItemCards` con `fromCartItems` (borrador).
- `admin_order_detail_screen.dart` — el ícono llama a
  `shareKitchenItemCards` con `fromAdminOrder`.
- `app_es.arb` — se retiran las claves de plantilla de texto que ya
  no aplican (`shareWaHeader`, separadores); se conservan las de
  card (`shareWaWithout` `sin {option}`, `shareWaSaucesLine`
  `salsas: {names}`, `shareWaNoteLabel`, `shareWaTotalLabel`,
  servicios) + `adminShareWhatsApp*` (CTA, tooltip, toast) y una
  nueva `shareWaItemIndex` si hace falta para "i/n".
- `pubspec.yaml` — `share_plus` (versión estable ≥7 días).
- `lib/l10n/app_localizations*.dart` — regen.

### Tests

- `kitchen_item_card_test.dart` — render: `RepaintBoundary` +
  `KitchenItemCard` → PNG no vacío por ítem con data de mesa/
  pickup/domicilio; ítem sin mods; nota vacía no se pinta.
- `admin_new_order_screen_test.dart` — "Enviar a cocina" →
  `Share.shareXFiles` llamado con N archivos (stub del channel
  `dev.fluttercommunity.plus/share`); fallo de plataforma → toast.
- `admin_order_detail_screen_test.dart` — ícono → mismo share con
  el pedido hidratado.
- Se retiran los tests de plantilla de texto (`buildKitchenOrderMessage`)
  y de URL `wa.me`.

## Fuera de alcance (declarado)

- Texto `wa.me/<número>` (V1) — descartado por el dueño; el número
  directo pierde sentido sin texto (`wa.me` no lleva media).
- Imagen-ticket única (versión B) — el dueño eligió card por ítem.
- Foto del producto en la card — descartada explícitamente.
- Compartir a otros destinos — el share sheet ya lo permite gratis.
- `whatsapp://send` con scheme propio — descartado.

## Verificación

- `flutter analyze` 0 issues + tests admin verdes (nuevos incluidos).
- Emulador: crear pedido → "Enviar a cocina" → share sheet abre con
  N imágenes → reenviar a WhatsApp muestra la galería de cards; el
  ícono del detalle lanza lo mismo con el pedido hidratado.
- design-system.yaml: sección `kitchen_item_card` + changelog
  post-gate.
