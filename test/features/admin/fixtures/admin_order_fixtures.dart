import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/get_admin_order_detail_use_case.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_queue_use_case.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/update_admin_order_status_use_case.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

/// Fixtures del tab Cocina — los mocks de fase 1 movidos verbatim del
/// cubit (§038): la cola sale de mocks pero las pantallas/tests siguen
/// necesitando la semilla completa de variantes.

/// Cola viva mock (§036): todos los carriles poblados con todas
/// las variantes — la puerta de confirmación queda a la vista en
/// Pendiente: la recogida PRESENCIAL sin cobrar (mostrador/
/// teléfono, pending/failed) se bloquea a "Registrar pago" y el
/// resto confirma libre; la recogida ONLINE solo acepta Nequi —
/// se congela hasta el webhook (pending = rótulo de espera,
/// failed = solo cancelar; ya pagado fluye normal).
/// canales online/presencial, serviceType pickup/delivery/
/// dineIn, pago efectivo/transferencia/nequi en los 3 estados. El
/// cierre muestra el desglose de métodos.
List<AdminOrder> adminActiveFixtures() {
  final now = DateTime.now();
  return [
    // PENDIENTE — online delivery, transfer pendiente. El caso
    // "me escriben por WhatsApp que ya pagaron" del dueño.
    AdminOrder(
      id: 'adm-1',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 2,
          unitPrice: 25000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ing-cebolla',
              optionName: 'Cebolla',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
            CartModifier(
              optionId: 'ex-queso',
              optionName: 'Queso cheddar',
              action: CartModifierAction.added,
              priceDelta: 2500,
              group: CartModifierGroup.extra,
            ),
            CartModifier(
              optionId: 'sa-pina',
              optionName: 'Piña',
              action: CartModifierAction.added,
              priceDelta: 0,
              group: CartModifierGroup.sauce,
            ),
          ],
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 6000,
          includedNames: ['Papas criollas', 'Queso', 'Salsas de la casa'],
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 56000,
      deliveryFee: 5000,
      placedAt: now.subtract(const Duration(minutes: 12)),
      customerName: 'Ana Uno',
      addressLabel: 'Casa',
      landmark: 'Portón negro frente a la cancha',
      neighborhood: 'Barrio La Esperanza',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2442,
      locationLng: -75.5812,
      contactPhone: '3001234567',
      note: 'Sin picante — es para el niño',
    ),
    // CONFIRMADO — dine_in Mesa 3, cash pendiente (cobrar no es
    // la acción de card en estados tempranos — en mesa se sirve
    // antes de cobrar).
    AdminOrder(
      id: 'adm-2',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 9)),
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 1,
          unitPrice: 14000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 14000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 4)),
      tableLabel: 'Mesa 3',
    ),
    // CONFIRMADO — presencial mostrador pagado (adm-4 pasa de
    // received a confirmed: el backend §019 crea presenciales ya
    // confirmados — un 'received' presencial es contrato viejo).
    AdminOrder(
      id: 'adm-4',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 8)),
      items: const [
        OrderItem(
          productId: 'p-coyote',
          productSlug: 'coyote',
          name: 'El Coyote',
          quantity: 2,
          unitPrice: 18000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ing-cebolla',
              optionName: 'Cebolla',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
            CartModifier(
              optionId: 'sa-pina',
              optionName: 'Piña',
              action: CartModifierAction.added,
              priceDelta: 0,
              group: CartModifierGroup.sauce,
            ),
          ],
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 36000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 1)),
    ),
    // CONFIRMADO — online delivery NEQUI ya pagado: el webhook
    // llegó primero y confirmó — el pedido fluye normal (acción
    // "Preparar"); contracara de los Nequi congelados en
    // Pendiente (§036).
    AdminOrder(
      id: 'adm-32',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 7)),
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 25000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(minutes: 3)),
      customerName: 'Wanda Treintaidós',
      addressLabel: 'Trabajo',
      landmark: 'Edificio azul de la esquina, segundo piso',
      neighborhood: 'Barrio El Centro',
      contactPhone: '3019876543',
    ),
    // PREPARANDO — Mesa 5 (la orden grande) dine_in cash paid:
    // 1× de cada producto del menú (7 líneas) — cubre el resumen
    // largo de la card (maxLines 2 → la cola real trunca con "…").
    AdminOrder(
      id: 'adm-7',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.preparing,
      statusChangedAt: now.subtract(const Duration(minutes: 5)),
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ing-cebolla',
              optionName: 'Cebolla',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
            CartModifier(
              optionId: 'ex-tocineta',
              optionName: 'Tocineta',
              action: CartModifierAction.added,
              priceDelta: 3500,
              group: CartModifierGroup.extra,
            ),
          ],
        ),
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 1,
          unitPrice: 17000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ex-queso',
              optionName: 'Queso cheddar',
              action: CartModifierAction.added,
              priceDelta: 2500,
              group: CartModifierGroup.extra,
            ),
          ],
        ),
        OrderItem(
          productId: 'p-coyote',
          productSlug: 'coyote',
          name: 'El Coyote',
          quantity: 1,
          unitPrice: 18000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
        ),
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 1,
          unitPrice: 18000,
          modifiers: [
            CartModifier(
              optionId: 'ing-tomate',
              optionName: 'Tomate',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
            CartModifier(
              optionId: 'sa-pina',
              optionName: 'Piña',
              action: CartModifierAction.added,
              priceDelta: 0,
              group: CartModifierGroup.sauce,
            ),
          ],
        ),
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 1,
          unitPrice: 16000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ing-repollo',
              optionName: 'Repollo',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
          ],
        ),
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 1,
          unitPrice: 14000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de Papas',
          quantity: 1,
          unitPrice: 10000,
          includedNames: ['Papas criollas', 'Queso', 'Salsas de la casa'],
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 118000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 8)),
      tableLabel: 'Mesa 5',
      note: 'Uno sin cebolla porfa',
    ),
    // PENDIENTE — online pickup NEQUI FALLIDO: el webhook ya
    // rechazó el cobro — online pickup SOLO acepta Nequi (§036:
    // efectivo/transfer dejan al cliente ghostear la producción);
    // sin botones, la única salida es cancelar.
    AdminOrder(
      id: 'adm-9',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-coyote',
          productSlug: 'coyote',
          name: 'El Coyote',
          quantity: 2,
          unitPrice: 18000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.failed,
      subtotal: 46000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 3)),
      customerName: 'Daniela Cuatro',
      contactPhone: '3171234567',
    ),
    // PENDIENTE — online delivery, transfer pendiente, pedido
    // de ítem único grande.
    AdminOrder(
      id: 'adm-10',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 3,
          unitPrice: 16000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 48000,
      deliveryFee: 4000,
      placedAt: now.subtract(const Duration(minutes: 2)),
      customerName: 'Elena Cinco',
      addressLabel: 'Casa',
      landmark: 'Al lado de la tienda Don Pedro',
      neighborhood: 'Barrio San José',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2518,
      locationLng: -75.5636,
      contactPhone: '3023456789',
    ),
    // PENDIENTE — online delivery PAGADO: prepaid, confirma sin
    // fricción (contracara de los delivery sin cobrar).
    AdminOrder(
      id: 'adm-20',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 1,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 18000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(minutes: 11)),
      customerName: 'Mario Doce',
      addressLabel: 'Casa de mi mamá',
      landmark: 'Casa verde de dos pisos',
      neighborhood: 'Barrio La Floresta',
      contactPhone: '3104567890',
    ),
    // PENDIENTE — online delivery CONTRAENTREGA (efectivo en la
    // puerta): pidió por la app y paga al recibir — SÍ confirma
    // porque la entrega la hace el dueño y nada sale sin él; el
    // cobro se registra con "Registrar pago" en la puerta.
    AdminOrder(
      id: 'adm-28',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 1,
          unitPrice: 17000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 6000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 23000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(minutes: 7)),
      customerName: 'Pablo Veintiocho',
      addressLabel: 'Casa',
      landmark: 'Frente a la iglesia',
      neighborhood: 'Barrio El Carmen',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2309,
      locationLng: -75.5901,
      contactPhone: '3115678901',
    ),
    // PENDIENTE — online pickup NEQUI esperando webhook (§036):
    // el cobro dentro de la app no lo toca el dueño — la card
    // muestra el rótulo de espera, sin botones.
    AdminOrder(
      id: 'adm-29',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 2,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 36000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 6)),
      customerName: 'Tomás Veintinueve',
      contactPhone: '3182345678',
    ),
    // PENDIENTE — online delivery NEQUI esperando webhook: la
    // regla congela TAMBIÉN el domicilio — aunque el dueño
    // entregue, ni Confirmar ni Registrar pago existen hasta
    // que el webhook hable (decisión §036).
    AdminOrder(
      id: 'adm-30',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 2,
          unitPrice: 16000,
          includedNames: [
            'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
          ],
          modifiers: [
            CartModifier(
              optionId: 'ing-repollo',
              optionName: 'Repollo',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
            CartModifier(
              optionId: 'ex-tocineta',
              optionName: 'Tocineta',
              action: CartModifierAction.added,
              priceDelta: 3500,
              group: CartModifierGroup.extra,
            ),
          ],
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 32000,
      deliveryFee: 4000,
      placedAt: now.subtract(const Duration(minutes: 5)),
      customerName: 'Uriel Treinta',
      addressLabel: 'Oficina',
      landmark: 'Local 4, centro comercial La Esquina',
      neighborhood: 'Barrio El Centro',
      contactPhone: '3126789012',
    ),
    // PENDIENTE — online pickup NEQUI FALLIDO: el webhook ya
    // reportó el rechazo — sin botones de avance ni cobro, la
    // única salida es cancelar (decisión §036).
    AdminOrder(
      id: 'adm-31',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 1,
          unitPrice: 14000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.failed,
      subtotal: 14000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 2)),
      customerName: 'Valeria Treintaiuno',
      contactPhone: '3193456789',
    ),
    // PENDIENTE — online pickup NEQUI PAGADO: el webhook ya
    // confirmó — la recogida sí confirma (contracara de los
    // Nequi congelados).
    AdminOrder(
      id: 'adm-21',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 1,
          unitPrice: 16000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 16000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 10)),
      customerName: 'Nora Trece',
      contactPhone: '3204567890',
      note: 'La recoge mi hermano',
    ),
    // CONFIRMADO NATURAL — presencial delivery sin cobrar
    // (pedido tomado por teléfono): el dueño ES el confirmador —
    // nace confirmed como la mesa, nunca pisa Pendiente (§036);
    // el cobro se resuelve en la puerta al entregar.
    AdminOrder(
      id: 'adm-22',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 6)),
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 25000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(minutes: 9)),
      customerName: 'Óscar Catorce',
      addressLabel: 'Casa',
      landmark: 'Portón blanco con reja',
      neighborhood: 'Barrio La Esperanza',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2701,
      locationLng: -75.5723,
      contactPhone: '3137890123',
    ),
    // CONFIRMADO NATURAL — presencial dineIn cash pendiente
    // (Mesa 4): el dueño la tomó → nace confirmed (§036); en
    // mesa se sirve primero y se cobra cuando se van.
    AdminOrder(
      id: 'adm-23',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 5)),
      items: const [
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 2,
          unitPrice: 17000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 34000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 8)),
      tableLabel: 'Mesa 4',
    ),
    // CONFIRMADO NATURAL — presencial dineIn TRANSFER pendiente
    // (Mesa 6 paga QR al final): misma regla — nace confirmed,
    // el cobro se resuelve al cerrar la cuenta.
    AdminOrder(
      id: 'adm-27',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 4)),
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 3,
          unitPrice: 14000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 42000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 7)),
      tableLabel: 'Mesa 6',
    ),
    // PENDIENTE — online pickup NEQUI esperando webhook: online
    // pickup SOLO acepta Nequi (§036 — el efectivo/transfer deja
    // producción perdida si no recogen). La card espera el
    // webhook — sin botones.
    AdminOrder(
      id: 'adm-24',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-coyote',
          productSlug: 'coyote',
          name: 'El Coyote',
          quantity: 1,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.nequi,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 18000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 5)),
      customerName: 'Sara Quince',
      contactPhone: '3215678901',
    ),
    // PENDIENTE — presencial pickup (mostrador) cash PENDIENTE:
    // en mostrador se cobra al tomar — sin cobrar no entra a
    // cocina → BLOQUEADO, "Registrar pago". Variante mock: el presencial
    // podría nacer received si quedó sin cobrar (§022 la decide).
    AdminOrder(
      id: 'adm-25',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 1,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 18000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 4)),
    ),
    // PENDIENTE — presencial pickup (mostrador) cash PAGADO:
    // cobrado al tomarlo → SÍ confirma.
    AdminOrder(
      id: 'adm-26',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 1,
          unitPrice: 16000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 26000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 3)),
    ),
    // PENDIENTE — presencial pickup por TELÉFONO, transfer
    // PENDIENTE: el cliente dice "ya te transfiero" — presencial
    // sí admite transfer manual (el dueño la certifica con
    // "Registrar pago"); sin plata no entra a cocina → BLOQUEADO.
    // La prohibición de transfer solo es para online (§036).
    AdminOrder(
      id: 'adm-33',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.received,
      items: const [
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 1,
          unitPrice: 17000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 17000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 1)),
    ),
    // CONFIRMADO — online delivery YA PAGADO por adelantado: la
    // cocina prepara sin preocuparse por el cobro.
    AdminOrder(
      id: 'adm-11',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.confirmed,
      statusChangedAt: now.subtract(const Duration(minutes: 3)),
      items: const [
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 2,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 36000,
      deliveryFee: 4000,
      placedAt: now.subtract(const Duration(minutes: 6)),
      customerName: 'Felipe Seis',
      addressLabel: 'Casa',
      landmark: 'Al final del callejón, casa amarilla',
      neighborhood: 'Barrio San Antonio',
      contactPhone: '3148901234',
    ),
    // PREPARANDO — online pickup sin cobrar (el cliente paga
    // transfer al recoger — pickup no acepta efectivo).
    AdminOrder(
      id: 'adm-12',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.preparing,
      statusChangedAt: now.subtract(const Duration(minutes: 3)),
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 25000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 5)),
      customerName: 'Gabriel Siete',
      contactPhone: '3226789012',
    ),
    // PREPARANDO — online delivery pagado.
    AdminOrder(
      id: 'adm-13',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.preparing,
      statusChangedAt: now.subtract(const Duration(minutes: 1)),
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 2,
          unitPrice: 14000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 6000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 34000,
      deliveryFee: 4000,
      placedAt: now.subtract(const Duration(minutes: 7)),
      customerName: 'Héctor Ocho',
      addressLabel: 'Trabajo',
      landmark: 'Bodega de la esquina, preguntar por él',
      neighborhood: 'Barrio El Progreso',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2178,
      locationLng: -75.6044,
      contactPhone: '3159012345',
    ),
    // LISTO delivery pagado — "Entregado" (ya salió en camino
    // cobrado).
    AdminOrder(
      id: 'adm-14',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.ready,
      statusChangedAt: now.subtract(const Duration(minutes: 7)),
      items: const [
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 1,
          unitPrice: 17000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 27000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(minutes: 22)),
      customerName: 'Inés Nueve',
      addressLabel: 'Casa',
      landmark: 'Casa rosada junto al parqueadero',
      neighborhood: 'Barrio La Paz',
      contactPhone: '3160123456',
    ),
    // LISTO dine_in YA COBRADO — Mesa 1: "Entregado" libera la
    // mesa (la contracara de Mesa 7, que aún debe).
    AdminOrder(
      id: 'adm-15',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.ready,
      statusChangedAt: now.subtract(const Duration(minutes: 5)),
      items: const [
        OrderItem(
          productId: 'p-coyote',
          productSlug: 'coyote',
          name: 'El Coyote',
          quantity: 2,
          unitPrice: 18000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 36000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 30)),
      tableLabel: 'Mesa 1',
    ),
    // ENTREGADO dine_in cash — segundo método para el resumen
    // del cierre (efectivo + transferencia en el desglose).
    AdminOrder(
      id: 'adm-16',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.done,
      statusChangedAt: now.subtract(const Duration(minutes: 8)),
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 1,
          unitPrice: 16000,
        ),
        OrderItem(
          productId: 'p-papas',
          productSlug: 'manada-papas',
          name: 'Manada de papas',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 26000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(hours: 4)),
      tableLabel: 'Mesa 9',
    ),
    // ENTREGADO online pickup transfer — tercer entregado.
    AdminOrder(
      id: 'adm-17',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.done,
      statusChangedAt: now.subtract(const Duration(minutes: 5)),
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 1,
          unitPrice: 14000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 14000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(hours: 2)),
      customerName: 'Jorge Diez',
      contactPhone: '3237890123',
    ),
    // LISTO pickup pagado — Beto ya está en `ready`: su acción
    // de card es "Entregado" (pagado), no el label del paso.
    AdminOrder(
      id: 'adm-3',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.pickup,
      status: OrderStatus.ready,
      statusChangedAt: now.subtract(const Duration(minutes: 3)),
      items: const [
        OrderItem(
          productId: 'p-ave',
          productSlug: 'ave-presa',
          name: 'Ave de Presa',
          quantity: 1,
          unitPrice: 18000,
        ),
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 1,
          unitPrice: 16000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 34000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 26)),
      customerName: 'Beto Dos',
      contactPhone: '3248901234',
    ),
    // LISTO dine_in sin cobrar — Mesa 7: la card muestra "Me
    // pagó" (el cobro bloquea el Entregado — caso del §022).
    AdminOrder(
      id: 'adm-8',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.ready,
      statusChangedAt: now.subtract(const Duration(minutes: 1)),
      items: const [
        OrderItem(
          productId: 'p-carnicero',
          productSlug: 'carnicero',
          name: 'El Carnicero',
          quantity: 1,
          unitPrice: 17000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.pending,
      subtotal: 17000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(minutes: 18)),
      tableLabel: 'Mesa 7',
    ),
    // ENTREGADO sin cerrar — Carla done pagado: vive en `active`
    // hasta el cierre (el mock demuestra el modelo nuevo).
    AdminOrder(
      id: 'adm-5',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.done,
      statusChangedAt: now.subtract(const Duration(minutes: 2)),
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 22000,
      deliveryFee: 3000,
      placedAt: now.subtract(const Duration(hours: 3)),
      customerName: 'Carla Tres',
      addressLabel: 'Casa',
      landmark: 'Segunda casa después de la bomba',
      neighborhood: 'Barrio El Prado',
      hasLocationPin: true,
      locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
      locationLat: 6.2567,
      locationLng: -75.5988,
      contactPhone: '3171234567',
    ),
  ];
}

/// Historial mock (§036): solo el cancelado — el done migró a la
/// cola viva (espera el cierre de caja para archivarse).
List<AdminOrder> adminHistoryFixtures() {
  final now = DateTime.now();
  return [
    AdminOrder(
      id: 'adm-6',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.cancelled,
      items: const [
        OrderItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          name: 'El Cachorro',
          quantity: 2,
          unitPrice: 14000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      // Se canceló antes de cobrar — el backend marca el pago
      // failed al cancelar con cobro pendiente (§019); card y
      // detalle lo suprimen en terminal (deuda fantasma, §034).
      paymentStatus: OrderPaymentStatus.failed,
      subtotal: 28000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(hours: 5)),
      tableLabel: 'Mesa 2',
    ),
    // Cancelado CON MOTIVO — el historial/detalle muestra la
    // razón que el dueño dejó.
    AdminOrder(
      id: 'adm-18',
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: OrderStatus.cancelled,
      items: const [
        OrderItem(
          productId: 'p-depredador',
          productSlug: 'depredador',
          name: 'El Depredador',
          quantity: 1,
          unitPrice: 25000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.transfer,
      paymentStatus: OrderPaymentStatus.failed,
      subtotal: 21000,
      deliveryFee: 4000,
      placedAt: now.subtract(const Duration(hours: 7)),
      customerName: 'Karla Once',
      addressLabel: 'Casa',
      landmark: 'Frente al colegio',
      neighborhood: 'Barrio Versalles',
      contactPhone: '3182345678',
      cancelReason: 'El cliente no contestó al confirmar',
    ),
    // Cancelado YA COBRADO — caso borde: la plata entró y hay
    // que devolverla; el historial no puede esconderlo.
    AdminOrder(
      id: 'adm-19',
      channel: AdminOrderChannel.presencial,
      serviceType: AdminServiceType.dineIn,
      status: OrderStatus.cancelled,
      items: const [
        OrderItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          name: 'La Trampa',
          quantity: 2,
          unitPrice: 16000,
        ),
      ],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      subtotal: 32000,
      deliveryFee: 0,
      placedAt: now.subtract(const Duration(hours: 6)),
      tableLabel: 'Mesa 8',
      cancelReason: 'El cliente pidió otro plato en su lugar',
    ),
  ];
}

/// Use case falso para tests de cubit/pantallas — devuelve las listas
/// dadas envueltas en el resultado (convención: fixtures + mocktail).
class FakeLoadAdminQueueUseCase extends Mock
    implements LoadAdminQueueUseCase {}

/// Use case falso del detalle (§039 — GET /admin/orders/:id): stub
/// de refreshOrder — el test lo arma con su propio when().
class FakeGetAdminOrderDetailUseCase extends Mock
    implements GetAdminOrderDetailUseCase {}

/// Use case falso del PATCH status (§040 — PATCH
/// /admin/orders/:id/status): el test lo arma con su propio when() o
/// con `stubUpdateEcho` (mini-backend que aplica el `to` pedido).
class FakeUpdateAdminOrderStatusUseCase extends Mock
    implements UpdateAdminOrderStatusUseCase {}

/// Stub "mini-backend" del PATCH status: aplica el `to` pedido sobre
/// la orden conocida por id y devuelve la entidad con el estado nuevo
/// — `copyWith` re-sella `statusChangedAt` igual que el servidor
/// (§040). El `cancelReason` viaja solo cuando viene (cancel sin
/// motivo deja el campo en null). Id desconocido → Left como un 404.
void stubUpdateEcho(
  FakeUpdateAdminOrderStatusUseCase update,
  List<AdminOrder> known,
) {
  final byId = {for (final o in known) o.id: o};
  when(
    () => update.call(
      any(),
      to: any(named: 'to'),
      cancelReason: any(named: 'cancelReason'),
    ),
  ).thenAnswer((inv) async {
    final id = inv.positionalArguments.first as String;
    final to = inv.namedArguments[#to] as String;
    final reason = inv.namedArguments[#cancelReason] as String?;
    final base = byId[id];
    if (base == null) {
      return const Left<AdminFailure, AdminOrder>(
        AdminServerFailure('ORDER_NOT_FOUND'),
      );
    }
    final next = switch (to) {
      'confirmed' => OrderStatus.confirmed,
      'preparing' => OrderStatus.preparing,
      'ready' => OrderStatus.ready,
      'done' => OrderStatus.done,
      'cancelled' => OrderStatus.cancelled,
      _ => base.status,
    };
    return Right<AdminFailure, AdminOrder>(
      base.copyWith(status: next, cancelReason: reason),
    );
  });
}

/// Cubit listo para tests: `load()` devuelve las fixtures (o las listas
/// inyectadas) — sustituye al viejo `AdminQueueCubit(mockActive:…)`.
/// `getOrderDetail` (§039): sin inyección queda en Left silencioso —
/// las pantallas disparan refreshOrder al montar el detalle y los
/// tests que no lo ejercen no notan el fetch.
/// `updateOrderStatus` (§040): sin inyección queda en `stubUpdateEcho`
/// sobre las mismas listas servidas por load — el PATCH "responde"
/// como el backend (estado nuevo + statusChangedAt re-sellado).
AdminQueueCubit buildAdminQueueCubit({
  List<AdminOrder>? active,
  List<AdminOrder>? history,
  AdminFailure? activeFailure,
  AdminFailure? historyFailure,
  FakeGetAdminOrderDetailUseCase? getOrderDetail,
  FakeUpdateAdminOrderStatusUseCase? updateOrderStatus,
}) {
  final useCase = FakeLoadAdminQueueUseCase();
  final detail = getOrderDetail ?? FakeGetAdminOrderDetailUseCase();
  final update = updateOrderStatus ?? FakeUpdateAdminOrderStatusUseCase();
  if (getOrderDetail == null) {
    when(() => detail.call(any())).thenAnswer(
      (_) async => const Left(AdminServerFailure('stub')),
    );
  }
  final activeList = active ?? adminActiveFixtures();
  final historyList = history ?? adminHistoryFixtures();
  // El echo se siembra con las MISMAS listas que load() sirve — la
  // mutación encuentra por id la orden que el state cargó.
  if (updateOrderStatus == null) {
    stubUpdateEcho(update, [...activeList, ...historyList]);
  }
  when(useCase.call).thenAnswer(
    (_) async => AdminQueueData(
      active: activeFailure != null ? Left(activeFailure) : Right(activeList),
      history: historyFailure != null
          ? Left(historyFailure)
          : Right(
              AdminHistoryPage(items: historyList, total: historyList.length),
            ),
    ),
  );
  return AdminQueueCubit(
    loadQueue: useCase,
    getOrderDetail: detail,
    updateOrderStatus: update,
  );
}
