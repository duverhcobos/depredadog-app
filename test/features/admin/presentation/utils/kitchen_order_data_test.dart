import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/utils/kitchen_order_data.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

/// Tests de la data de la comanda de cocina (§043 v5): el reparto
/// por SECCIONES (Se le quitó / Ingredientes / Adicionales /
/// Toppings / Salsas — el del desplegable del tile §021b), las
/// líneas de servicio por tipo y los dos mappers (borrador de la
/// comanda y detalle) — la card solo compone, toda la resolución
/// vive acá.
void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

  /// AdminOrder mínimo — la data solo lee servicio, pago, hora,
  /// ítems, entrega, nota, total y número; el resto queda default.
  AdminOrder order({
    String id = 'ord-1',
    AdminOrderChannel channel = AdminOrderChannel.presencial,
    AdminServiceType serviceType = AdminServiceType.dineIn,
    List<OrderItem> items = const [],
    AdminPaymentMethod paymentMethod = AdminPaymentMethod.cash,
    int subtotal = 0,
    int deliveryFee = 0,
    DateTime? placedAt,
    String? tableLabel,
    String? addressLabel,
    String? landmark,
    String? neighborhood,
    String? contactPhone,
    String? note,
    int? orderNumber,
  }) => AdminOrder(
    id: id,
    channel: channel,
    serviceType: serviceType,
    status: OrderStatus.confirmed,
    items: items,
    paymentMethod: paymentMethod,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    placedAt: placedAt ?? DateTime(2026, 11, 8, 12, 40),
    tableLabel: tableLabel,
    addressLabel: addressLabel,
    landmark: landmark,
    neighborhood: neighborhood,
    contactPhone: contactPhone,
    note: note,
    orderNumber: orderNumber,
  );

  group('KitchenOrderData.fromAdminOrder (§043 — detalle)', () {
    test('domicilio: número adm-N, línea "Domicilio" + entrega en '
        'una línea + teléfono, mods repartidos, nota y total del '
        'servidor', () {
      final o = order(
        id: 'adm-1',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        orderNumber: 1, // shortTag → 'adm-1'
        paymentMethod: AdminPaymentMethod.transfer,
        subtotal: 56000,
        deliveryFee: 5000,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 2,
            unitPrice: 25000,
            includedNames: ['Pan', 'Salchicha americana'],
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              // Reemplazo del agotado — la fila added no repite
              // nombre: se lee 'Mozzarella → Tostacos' en Se le quitó.
              CartModifier(
                optionId: 'ing-mozzarella',
                optionName: 'Queso mozzarella',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'ing-tostacos',
                optionName: 'Tostacos',
                action: CartModifierAction.added,
                priceDelta: 0,
                group: CartModifierGroup.ingredient,
                replacesOptionId: 'ing-mozzarella',
              ),
              CartModifier(
                optionId: 'ex-queso',
                optionName: 'Queso cheddar',
                action: CartModifierAction.added,
                priceDelta: 2500,
                group: CartModifierGroup.extra,
              ),
              CartModifier(
                optionId: 'to-maiz',
                optionName: 'Maíz dulce',
                action: CartModifierAction.added,
                priceDelta: 0,
                group: CartModifierGroup.topping,
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
          ),
        ],
        addressLabel: 'Casa',
        landmark: 'Portón negro frente a la cancha',
        neighborhood: 'Barrio La Esperanza',
        contactPhone: '3001234567',
        note: 'Sin picante — es para el niño',
      );

      final data = KitchenOrderData.fromAdminOrder(o, l10n);

      expect(data.number, 'adm-1');
      expect(data.paymentMethod, AdminPaymentMethod.transfer);
      // La primera línea siempre es el servicio solo; el domicilio
      // agrega dirección+referencia en UNA línea y el teléfono en
      // otra (el dueño reparte — mismo criterio del detalle §037).
      expect(data.serviceLines, [
        'Domicilio',
        'Casa · Portón negro frente a la cancha · Barrio La Esperanza',
        'Recibe: 300 123 4567',
      ]);
      expect(data.items, [
        const KitchenOrderLine(
          quantity: 2,
          name: 'El Depredador',
          sections: [
            KitchenSection(
              title: 'Se le quitó',
              names: ['Cebolla', 'Queso mozzarella → Tostacos'],
            ),
            KitchenSection(
              title: 'Ingredientes',
              names: ['Pan', 'Salchicha americana'],
            ),
            KitchenSection(title: 'Adicionales', names: ['Queso cheddar']),
            KitchenSection(title: 'Toppings', names: ['Maíz dulce']),
            KitchenSection(title: 'Salsas', names: ['Piña']),
          ],
        ),
        const KitchenOrderLine(quantity: 1, name: 'Manada de papas'),
      ]);
      expect(data.note, 'Sin picante — es para el niño');
      // El total del servidor con domicilio — sin precio por ítem.
      expect(data.total, 61000);
    });

    test('pickup lleva solo "Para llevar"; dineIn sin mesa cae a '
        '"En el local" — sin líneas extra de entrega', () {
      final pickup = KitchenOrderData.fromAdminOrder(
        order(serviceType: AdminServiceType.pickup),
        l10n,
      );
      expect(pickup.serviceLines, ['Para llevar']);

      final sinMesa = KitchenOrderData.fromAdminOrder(
        order(serviceType: AdminServiceType.dineIn),
        l10n,
      );
      expect(sinMesa.serviceLines, ['En el local']);
    });

    test('sin orderNumber el número cae a la cola del id '
        '(shortTag — mismo formato del detalle)', () {
      final data = KitchenOrderData.fromAdminOrder(
        order(id: 'a1b2c3d4e5', orderNumber: null),
        l10n,
      );
      expect(data.number, 'c3d4e5');
    });
  });

  group('KitchenOrderData.fromCartItems (§043 — borrador)', () {
    const sinCebolla = CartModifier(
      optionId: 'o-cebolla',
      optionName: 'Cebolla',
      action: CartModifierAction.removed,
      priceDelta: 0,
    );
    const conTocineta = CartModifier(
      optionId: 'o-tocineta',
      optionName: 'Tocineta crocante',
      action: CartModifierAction.added,
      priceDelta: 4000,
      group: CartModifierGroup.extra,
    );

    final cachorro = CartItem(
      id: 'comanda-1',
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: const [sinCebolla, conTocineta],
      includedNames: const ['Pan', 'Salchicha'],
      quantity: 2,
    );

    test('arma la comanda del borrador: shortTag adm-N (el MISMO del '
        'detalle), mesa del draft, mods 1:1 y nota propia', () {
      final created = order(
        orderNumber: 8,
        tableLabel: 'Mesa 2',
        subtotal: 18000,
      );
      final data = KitchenOrderData.fromCartItems(
        [cachorro],
        order: created,
        tableLabel: 'Mesa 2',
        note: 'empacar aparte',
        l10n: l10n,
      );

      // revisor-ui §043: '#8' al crear vs '#adm-8' en el detalle leía
      // a cocina como dos pedidos — un solo identificador en ambos.
      expect(data.number, 'adm-8');
      expect(data.serviceLines, ['Mesa 2']);
      expect(data.paymentMethod, AdminPaymentMethod.cash);
      expect(data.items, [
        const KitchenOrderLine(
          quantity: 2,
          name: 'El Cachorro',
          sections: [
            KitchenSection(title: 'Se le quitó', names: ['Cebolla']),
            KitchenSection(title: 'Ingredientes', names: ['Pan', 'Salchicha']),
            KitchenSection(title: 'Adicionales', names: ['Tocineta crocante']),
          ],
        ),
      ]);
      expect(data.note, 'empacar aparte');
      expect(data.total, 18000);
    });

    test('la mesa del BORRADOR gana sobre la del POST — si el '
        'response no la devolvió, la elegida sigue saliendo', () {
      final created = order(orderNumber: 8); // sin tableLabel
      final data = KitchenOrderData.fromCartItems(
        [cachorro],
        order: created,
        tableLabel: 'Mesa 2',
        l10n: l10n,
      );
      expect(data.serviceLines, ['Mesa 2']);
    });
  });
}
