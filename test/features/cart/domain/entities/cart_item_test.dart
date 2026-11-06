import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';

/// Ítem de apoyo: El Cachorro base $14.000 con la personalización
/// que se indique.
CartItem _item({
  String id = 'cart-1',
  String productId = 'p-cachorro',
  List<CartModifier> modifiers = const [],
  int quantity = 1,
}) => CartItem(
  id: id,
  productId: productId,
  productSlug: 'cachorro',
  productName: 'El Cachorro',
  unitBase: 14000,
  modifiers: modifiers,
  quantity: quantity,
);

const _sinMozzarella = CartModifier(
  optionId: 'o-mozzarella',
  optionName: 'Queso mozzarella',
  action: CartModifierAction.removed,
  priceDelta: 0,
);
const _extraTocineta = CartModifier(
  optionId: 'o-tocineta',
  optionName: 'Tocineta crocante',
  action: CartModifierAction.added,
  priceDelta: 4000,
);
const _ripioGratis = CartModifier(
  optionId: 'o-ripio',
  optionName: 'Papa ripio',
  action: CartModifierAction.added,
  priceDelta: 0,
);

void main() {
  group('CartItem.sameConfiguration', () {
    test('mismo producto + mismo conjunto en orden distinto → true', () {
      final a = _item(modifiers: const [_sinMozzarella, _extraTocineta]);
      final b = _item(modifiers: const [_extraTocineta, _sinMozzarella]);
      expect(a.sameConfiguration(b), isTrue);
    });

    test('mismo producto + modificador distinto → false', () {
      final a = _item(modifiers: const [_sinMozzarella]);
      final b = _item(modifiers: const [_ripioGratis]);
      expect(a.sameConfiguration(b), isFalse);
    });

    test('mismo modificador, distinto producto → false', () {
      final a = _item(modifiers: const [_sinMozzarella]);
      final b = _item(productId: 'p-trampa', modifiers: const [_sinMozzarella]);
      expect(a.sameConfiguration(b), isFalse);
    });

    test('mismo producto, distinto número de modificadores → false', () {
      final a = _item(modifiers: const [_sinMozzarella]);
      final b = _item(modifiers: const [_sinMozzarella, _ripioGratis]);
      expect(a.sameConfiguration(b), isFalse);
    });

    test('sin modificadores + mismo producto → true', () {
      expect(_item().sameConfiguration(_item()), isTrue);
    });
  });

  group('CartItem.unitPrice / lineTotal', () {
    test('sin modificadores → unitPrice = base', () {
      expect(_item().unitPrice, 14000);
    });

    test('suma solo los added con precio — removed y gratis no cobran', () {
      final item = _item(
        modifiers: const [_sinMozzarella, _extraTocineta, _ripioGratis],
      );
      expect(item.unitPrice, 18000); // 14.000 + 4.000
    });

    test('lineTotal = unitPrice × quantity', () {
      final item = _item(modifiers: const [_extraTocineta], quantity: 3);
      expect(item.lineTotal, 54000); // 18.000 × 3
    });
  });
}
