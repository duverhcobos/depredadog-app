import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/data/models/admin_order_model.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

/// JSON del AdminOrderResponseDto (backend §019 + §022/§037) — ítem
/// completo con modifiers, dirección DESGL OSADA (§037.B), pin y
/// correlativo humano.
Map<String, dynamic> fullJson({
  String id = 'a1b2c3d4e5f6',
  int? orderNumber = 42,
  String channel = 'online',
  String serviceType = 'delivery',
  String status = 'confirmed',
  List<dynamic>? items,
  Map<String, dynamic>? payment = const {
    'method': 'transfer',
    'status': 'paid',
  },
  String? tableLabel,
  String? customerName = 'Ana Uno',
  String? cancelReason,
  String? deliveryAddressLabel = 'Casa',
  String? deliveryLandmark = 'Portón negro frente a la cancha',
  String? deliveryNeighborhood = 'Barrio La Esperanza',
  String? deliveryAddress,
  String? deliveryLocationLink = 'https://maps.app.goo.gl/xK9fP2AbCd3',
  String? contactPhone = '3001234567',
  String? notes = 'sin picante — es para el niño',
  String? statusChangedAt = '2026-11-08T18:05:00.000Z',
  int deliveryFee = 5000,
}) => {
  'id': id,
  'orderNumber': orderNumber,
  'channel': channel,
  'serviceType': serviceType,
  'status': status,
  'items':
      items ??
      [
        {
          'productId': 'p-depredador',
          'productSlug': 'depredador',
          'productName': 'El Depredador',
          'quantity': 2,
          'unitPrice': 25000,
          'includedNames': ['Pan artesanal', 'Salchicha', 'Papitas'],
          'modifiers': [
            {
              'optionId': 'opt-cebolla',
              'optionName': 'Cebolla',
              'action': 'removed',
              'priceDelta': 0,
              'modifierGroup': 'ingredients',
              'replacesOptionId': null,
            },
            {
              'optionId': 'opt-tocineta',
              'optionName': 'Tocineta',
              'action': 'added',
              'priceDelta': 3500,
              'modifierGroup': 'extras',
              'replacesOptionId': 'opt-cebolla',
            },
            {
              'optionId': 'opt-pina',
              'optionName': 'Piña',
              'action': 'added',
              'priceDelta': 0,
              'modifierGroup': 'sauces',
              'replacesOptionId': null,
            },
            {
              'optionId': 'opt-queso',
              'optionName': 'Queso cheddar',
              'action': 'added',
              'priceDelta': 2500,
              'modifierGroup': 'extras',
              'replacesOptionId': null,
            },
          ],
        },
      ],
  'payment': payment,
  'subtotal': 56000,
  'deliveryFee': deliveryFee,
  'createdAt': '2026-11-08T17:40:00.000Z',
  'statusChangedAt': statusChangedAt,
  'tableLabel': tableLabel,
  'customerName': customerName,
  'cancelReason': cancelReason,
  'deliveryAddressLabel': deliveryAddressLabel,
  'deliveryLandmark': deliveryLandmark,
  'deliveryNeighborhood': deliveryNeighborhood,
  'deliveryAddress': deliveryAddress,
  'deliveryLocationLink': deliveryLocationLink,
  'contactPhone': contactPhone,
  'notes': notes,
};

void main() {
  group('AdminOrderModel.fromJson (backend §019 + §022/§037)', () {
    test('mapeo completo delivery online: canal, dirección '
        'desglosada, pin canónico, contactPhone, notes→note, '
        'statusChangedAt y correlativo', () {
      final order = AdminOrderModel.fromJson(fullJson());

      expect(order.id, 'a1b2c3d4e5f6');
      expect(order.orderNumber, 42);
      expect(order.shortTag, 'adm-42'); // correlativo real → 'adm-N'
      expect(order.channel, AdminOrderChannel.online);
      expect(order.serviceType, AdminServiceType.delivery);
      expect(order.status, OrderStatus.confirmed);
      expect(order.paymentMethod, AdminPaymentMethod.transfer);
      expect(order.paymentStatus, OrderPaymentStatus.paid);
      expect(order.subtotal, 56000);
      expect(order.deliveryFee, 5000);
      expect(order.total, 61000);
      expect(
        order.placedAt,
        DateTime.parse('2026-11-08T17:40:00.000Z').toLocal(),
      );
      expect(
        order.statusChangedAt,
        DateTime.parse('2026-11-08T18:05:00.000Z').toLocal(),
      );
      expect(order.customerName, 'Ana Uno');
      // Dirección desglosada §037.B — cada campo a su slot.
      expect(order.addressLabel, 'Casa');
      expect(order.landmark, 'Portón negro frente a la cancha');
      expect(order.neighborhood, 'Barrio La Esperanza');
      // Pin canónico: el link viaja verbatim a locationUrl — la app
      // NUNCA lo reconstruye; hasLocationPin = link != null.
      expect(order.hasLocationPin, isTrue);
      expect(order.locationUrl, 'https://maps.app.goo.gl/xK9fP2AbCd3');
      expect(order.contactPhone, '3001234567');
      expect(order.note, 'sin picante — es para el niño'); // notes → note
      expect(order.cancelReason, isNull);
      expect(order.tableLabel, isNull);

      final item = order.items.single;
      expect(item.productId, 'p-depredador');
      expect(item.productSlug, 'depredador');
      expect(item.name, 'El Depredador'); // productName → name
      expect(item.quantity, 2);
      expect(item.unitPrice, 25000);
      expect(item.includedNames, ['Pan artesanal', 'Salchicha', 'Papitas']);
    });

    test('dine_in presencial con tableLabel; payment null → cash + '
        'pending defensivo (pedidos viejos sin fila de pago)', () {
      final order = AdminOrderModel.fromJson(
        fullJson(
          channel: 'presencial',
          serviceType: 'dine_in',
          status: 'confirmed',
          tableLabel: 'Mesa 3',
          customerName: null,
          payment: null,
          deliveryAddressLabel: null,
          deliveryLandmark: null,
          deliveryNeighborhood: null,
          deliveryLocationLink: null,
          contactPhone: null,
          notes: null,
          deliveryFee: 0,
        ),
      );

      expect(order.channel, AdminOrderChannel.presencial);
      expect(order.serviceType, AdminServiceType.dineIn);
      expect(order.tableLabel, 'Mesa 3');
      expect(order.customerName, isNull);
      // Sin fila de pago → la puerta de pago de Cocina lo trata
      // como "sin cobrar" (defensivo §038).
      expect(order.paymentMethod, AdminPaymentMethod.cash);
      expect(order.paymentStatus, OrderPaymentStatus.pending);
      expect(order.hasLocationPin, isFalse);
      expect(order.locationUrl, isNull);
      expect(order.landmark, isNull);
      expect(order.note, isNull);
    });

    test('status: pending→received y los seis valores del backend '
        'mapean; desconocido → received NUNCA terminal (revisor §027)', () {
      OrderStatus of(String s) =>
          AdminOrderModel.fromJson(fullJson(status: s)).status;
      expect(of('pending'), OrderStatus.received);
      expect(of('confirmed'), OrderStatus.confirmed);
      expect(of('preparing'), OrderStatus.preparing);
      expect(of('ready'), OrderStatus.ready);
      expect(of('done'), OrderStatus.done);
      expect(of('cancelled'), OrderStatus.cancelled);
      // Un status nuevo del backend es un pedido VIVO — nunca se
      // pinta "Cancelado"/"Entregado" por desconocido.
      expect(of('out_for_delivery'), OrderStatus.received);
      expect(of('whatever'), OrderStatus.received);
    });

    test('fallback §037.B: sin ficha de dirección el landmark cae al '
        'snapshot crudo deliveryAddress (pedidos por teléfono)', () {
      final order = AdminOrderModel.fromJson(
        fullJson(
          deliveryAddressLabel: null,
          deliveryLandmark: null,
          deliveryNeighborhood: null,
          deliveryAddress: 'Casa blanca frente a la cancha (Barrio Centro)',
        ),
      );

      expect(order.addressLabel, isNull);
      expect(
        order.landmark,
        'Casa blanca frente a la cancha (Barrio Centro)',
      );
      expect(order.neighborhood, isNull);
      // El desglose gana cuando existe — deliveryLandmark tiene
      // prioridad sobre el crudo.
      final conFicha = AdminOrderModel.fromJson(
        fullJson(deliveryAddress: 'Otro snapshot que no debe ganar'),
      );
      expect(conFicha.landmark, 'Portón negro frente a la cancha');
    });

    test('serviceType: delivery→delivery, dine_in→dineIn, pickup/'
        'otro→pickup; channel presencial→presencial, else→online', () {
      AdminServiceType st(String s) =>
          AdminOrderModel.fromJson(fullJson(serviceType: s)).serviceType;
      expect(st('delivery'), AdminServiceType.delivery);
      expect(st('dine_in'), AdminServiceType.dineIn);
      expect(st('pickup'), AdminServiceType.pickup);
      expect(st('otro'), AdminServiceType.pickup);

      AdminOrderChannel ch(String s) =>
          AdminOrderModel.fromJson(fullJson(channel: s)).channel;
      expect(ch('presencial'), AdminOrderChannel.presencial);
      expect(ch('online'), AdminOrderChannel.online);
      expect(ch('cualquier'), AdminOrderChannel.online);
    });

    test('modificadores viajan por el mapper compartido: removed y '
        'fila de reemplazo → ingredient; added por slug (sauces/'
        'extras); null legacy → extra', () {
      final order = AdminOrderModel.fromJson(fullJson());

      final m = order.items.single.modifiers;
      expect(m, hasLength(4));
      // removed siempre ingredient aunque el slug diga otra cosa.
      expect(m[0].action, CartModifierAction.removed);
      expect(m[0].group, CartModifierGroup.ingredient);
      // La fila del reemplazo (added + replacesOptionId) también
      // es ingredient — misma regla del detalle del producto.
      expect(m[1].action, CartModifierAction.added);
      expect(m[1].group, CartModifierGroup.ingredient);
      expect(m[1].replacesOptionId, 'opt-cebolla');
      expect(m[1].priceDelta, 3500);
      // added por slug: sauces → sauce; extras/otro → extra.
      expect(m[2].group, CartModifierGroup.sauce);
      expect(m[3].group, CartModifierGroup.extra);
      expect(m[3].priceDelta, 2500);

      // modifierGroup null legacy → extra (fallback documentado).
      final legacy = AdminOrderModel.fromJson(
        fullJson(
          items: [
            {
              'productId': 'p-vieja',
              'productSlug': null,
              'productName': 'Perro viejo',
              'quantity': 1,
              'unitPrice': 12000,
              'includedNames': null,
              'modifiers': [
                {
                  'optionId': null,
                  'optionName': 'Extra viejo',
                  'action': 'added',
                  'priceDelta': 2000,
                  'modifierGroup': null,
                  'replacesOptionId': null,
                },
              ],
            },
          ],
        ),
      );
      final lm = legacy.items.single.modifiers.single;
      expect(lm.optionId, '');
      expect(lm.group, CartModifierGroup.extra);
      expect(legacy.items.single.productSlug, '');
      expect(legacy.items.single.includedNames, isEmpty);
    });

    test('payment: nequi→nequi; status pending/paid/failed mapean; '
        'cancelled trae su razón', () {
      final nequi = AdminOrderModel.fromJson(
        fullJson(payment: {'method': 'nequi', 'status': 'pending'}),
      );
      expect(nequi.paymentMethod, AdminPaymentMethod.nequi);
      expect(nequi.paymentStatus, OrderPaymentStatus.pending);

      // El backend real serializa method='gateway' + provider='nequi'
      // para el cobro por la app (verificado contra el DTO §038).
      final gateway = AdminOrderModel.fromJson(
        fullJson(
          payment: {'method': 'gateway', 'status': 'pending', 'provider': 'nequi'},
        ),
      );
      expect(gateway.paymentMethod, AdminPaymentMethod.nequi);

      final failed = AdminOrderModel.fromJson(
        fullJson(payment: {'method': 'cash', 'status': 'failed'}),
      );
      expect(failed.paymentMethod, AdminPaymentMethod.cash);
      expect(failed.paymentStatus, OrderPaymentStatus.failed);

      final cancelado = AdminOrderModel.fromJson(
        fullJson(
          status: 'cancelled',
          cancelReason: 'El cliente no contestó',
        ),
      );
      expect(cancelado.status, OrderStatus.cancelled);
      expect(cancelado.cancelReason, 'El cliente no contestó');
    });

    test('sin correlativo ni statusChangedAt → nulls; shortTag cae a '
        'la cola del id', () {
      final order = AdminOrderModel.fromJson(
        fullJson(orderNumber: null, statusChangedAt: null),
      );

      expect(order.orderNumber, isNull);
      expect(order.statusChangedAt, isNull);
      // Cola del id: 'a1b2c3d4e5f6' → últimos 6.
      expect(order.shortTag, 'd4e5f6');
    });
  });
}
