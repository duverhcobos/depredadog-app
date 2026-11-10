import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/data/models/customer_order_model.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

/// JSON del OrderResponseDto (§015/016) — con un ítem completo.
Map<String, dynamic> fullJson({
  String status = 'pending',
  String serviceType = 'delivery',
  Map<String, dynamic>? payment = const {
    'method': 'transfer',
    'status': 'paid',
  },
  List<dynamic>? items,
  String? deliveryAddress = 'Casa blanca frente a la cancha (El Carmen)',
  String? deliveryLocationLink = 'maps.app.goo.gl/xK9fP2AbCd3',
  String? contactPhone = '3001234567',
  String? notes = 'pago con billete de 50',
  String? cancelReason,
}) => {
  'id': 'ord-1',
  'serviceType': serviceType,
  'status': status,
  'items':
      items ??
      [
        {
          'productId': 'p-cachorro',
          'productSlug': 'cachorro',
          'productName': 'El Cachorro',
          'quantity': 2,
          'unitPrice': 14000,
          'includedNames': ['Pan brioche', 'Salchicha americana'],
          'modifiers': [
            {
              'optionId': 'opt-mozz',
              'optionName': 'Queso mozzarella',
              'action': 'removed',
              'priceDelta': 0,
              'modifierGroup': 'ingredients',
              'replacesOptionId': null,
            },
            {
              'optionId': 'opt-tostacos',
              'optionName': 'Tostacos',
              'action': 'added',
              'priceDelta': 0,
              'modifierGroup': 'extras',
              'replacesOptionId': 'opt-mozz',
            },
            {
              'optionId': 'opt-maiz',
              'optionName': 'Maíz tierno',
              'action': 'added',
              'priceDelta': 0,
              'modifierGroup': 'toppings',
              'replacesOptionId': null,
            },
            {
              'optionId': 'opt-rosada',
              'optionName': 'Salsa rosada',
              'action': 'added',
              'priceDelta': 0,
              'modifierGroup': 'sauces',
              'replacesOptionId': null,
            },
            {
              'optionId': 'opt-salami',
              'optionName': 'Salami',
              'action': 'added',
              'priceDelta': 3000,
              'modifierGroup': 'extras',
              'replacesOptionId': null,
            },
          ],
        },
      ],
  'payment': payment,
  'subtotal': 28000,
  'deliveryFee': 0,
  'createdAt': '2026-11-08T17:40:00.000Z',
  'deliveryAddress': deliveryAddress,
  'deliveryLocationLink': deliveryLocationLink,
  'contactPhone': contactPhone,
  'notes': notes,
  'cancelReason': cancelReason,
};

void main() {
  group('CustomerOrderModel.fromJson (§015/016)', () {
    test('parseo completo: ítem, modifiers por sección, entrega, '
        'pago y fecha a local', () {
      final order = CustomerOrderModel.fromJson(fullJson());

      expect(order.id, 'ord-1');
      expect(order.status, OrderStatus.received); // pending → received
      expect(order.serviceType, OrderServiceType.delivery);
      expect(order.paymentMethod, OrderPaymentMethod.nequi);
      expect(order.paymentStatus, OrderPaymentStatus.paid);
      expect(order.subtotal, 28000);
      expect(order.deliveryFee, 0);
      // 17:40Z → hora local del dispositivo.
      expect(
        order.placedAt,
        DateTime.parse('2026-11-08T17:40:00.000Z').toLocal(),
      );
      // deliveryAddress completo → landmark (snapshot único).
      expect(order.landmark, 'Casa blanca frente a la cancha (El Carmen)');
      expect(order.addressLabel, isNull);
      expect(order.neighborhood, isNull);
      expect(order.storeReference, isNull);
      expect(order.statusChangedAt, isNull);
      expect(order.hasLocationPin, isTrue);
      expect(order.contactPhone, '3001234567');
      expect(order.note, 'pago con billete de 50'); // notes → note
      expect(order.cancelReason, isNull);

      final item = order.items.single;
      expect(item.productId, 'p-cachorro');
      expect(item.productSlug, 'cachorro');
      expect(item.name, 'El Cachorro'); // productName → name
      expect(item.quantity, 2);
      expect(item.unitPrice, 14000);
      expect(item.includedNames, ['Pan brioche', 'Salchicha americana']);

      // Mapeo modifierGroup (slug) → CartModifierGroup — mismas
      // reglas del detalle del producto (§016).
      final m = item.modifiers;
      expect(m, hasLength(5));
      expect(m[0].action, CartModifierAction.removed);
      expect(m[0].group, CartModifierGroup.ingredient); // removed → ingredient
      // added + replacesOptionId → la fila del reemplazo es ingredient.
      expect(m[1].group, CartModifierGroup.ingredient);
      expect(m[1].replacesOptionId, 'opt-mozz');
      expect(m[2].group, CartModifierGroup.topping); // toppings
      expect(m[3].group, CartModifierGroup.sauce); // sauces
      expect(m[4].group, CartModifierGroup.extra); // extras/otro slug
      expect(m[4].priceDelta, 3000);
    });

    test('todos los status del backend mapean al enum app', () {
      OrderStatus of(String s) =>
          CustomerOrderModel.fromJson(fullJson(status: s)).status;
      expect(of('pending'), OrderStatus.received);
      expect(of('confirmed'), OrderStatus.confirmed);
      expect(of('preparing'), OrderStatus.preparing);
      expect(of('done'), OrderStatus.done);
      expect(of('cancelled'), OrderStatus.cancelled);
      // Desconocido → received defensivo: un status nuevo del
      // backend es un pedido VIVO, nunca se pinta "Cancelado"
      // (revisor §027).
      expect(of('whatever'), OrderStatus.received);
    });

    test('serviceType: delivery→delivery, pickup/otro→pickup', () {
      OrderServiceType of(String s) =>
          CustomerOrderModel.fromJson(fullJson(serviceType: s)).serviceType;
      expect(of('delivery'), OrderServiceType.delivery);
      expect(of('pickup'), OrderServiceType.pickup);
      expect(of('dine_in'), OrderServiceType.pickup);
    });

    test('payment: cash→onDelivery, transfer→nequi; status '
        'pending/paid/failed', () {
      final cash = CustomerOrderModel.fromJson(
        fullJson(payment: {'method': 'cash', 'status': 'pending'}),
      );
      expect(cash.paymentMethod, OrderPaymentMethod.onDelivery);
      expect(cash.paymentStatus, OrderPaymentStatus.pending);

      final failed = CustomerOrderModel.fromJson(
        fullJson(payment: {'method': 'transfer', 'status': 'failed'}),
      );
      expect(failed.paymentStatus, OrderPaymentStatus.failed);
    });

    test('payment:null → pending + nequi (defensivo pedidos sin '
        'fila)', () {
      final order = CustomerOrderModel.fromJson(fullJson(payment: null));
      expect(order.paymentStatus, OrderPaymentStatus.pending);
      expect(order.paymentMethod, OrderPaymentMethod.nequi);
    });

    test('NULL legacy: productSlug→\'\', includedNames→[], '
        'modifierGroup null→extra, sin pin ni dirección', () {
      final order = CustomerOrderModel.fromJson(
        fullJson(
          deliveryAddress: null,
          deliveryLocationLink: null,
          contactPhone: null,
          notes: null,
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

      final item = order.items.single;
      expect(item.productSlug, ''); // → fallback de marca en la card
      expect(item.includedNames, isEmpty); // sin sección "Lleva:"
      expect(item.modifiers.single.optionId, '');
      expect(item.modifiers.single.group, CartModifierGroup.extra);
      expect(order.landmark, isNull);
      expect(order.hasLocationPin, isFalse);
      expect(order.contactPhone, isNull);
      expect(order.note, isNull);
    });

    test('cancelled trae su razón; acción desconocida → removed '
        'defensivo', () {
      final order = CustomerOrderModel.fromJson(
        fullJson(
          status: 'cancelled',
          cancelReason: 'Cancelado por el cliente',
          items: [
            {
              'productId': 'p-1',
              'productSlug': 'x',
              'productName': 'X',
              'quantity': 1,
              'unitPrice': 1,
              'includedNames': const <dynamic>[],
              'modifiers': [
                {
                  'optionId': 'o-1',
                  'optionName': 'Queso',
                  'action': 'removed',
                  'priceDelta': 0,
                  'modifierGroup': 'toppings', // removed ignora el slug
                  'replacesOptionId': null,
                },
              ],
            },
          ],
        ),
      );

      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelReason, 'Cancelado por el cliente');
      // removed siempre ingredient aunque el slug diga toppings.
      expect(
        order.items.single.modifiers.single.group,
        CartModifierGroup.ingredient,
      );
    });
  });
}
