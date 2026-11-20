import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_group.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_option.dart';
import 'package:depredadog_app/features/home/presentation/utils/detail_selections.dart';

/// Cachorro simplificado para el mapeo CartItem → sets (§021): pan y
/// salchicha fijos incluidos, mozzarella y huevo incluidos removibles,
/// tocineta adicional cobrada; un topping y una salsa gratis.
CatalogProduct _cachorro() => const CatalogProduct(
  id: 'p-cachorro',
  slug: 'cachorro',
  name: 'El Cachorro',
  tagline: 'El primer mordisco de la manada.',
  basePrice: 14000,
  imageUrl: null,
  isAvailable: true,
  isFeatured: false,
  isCombo: false,
  modifierGroups: [
    ModifierGroup(
      id: 'g-ing',
      slug: 'ingredients',
      name: 'Ingredientes',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-pan',
          name: 'Pan artesanal',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: true,
        ),
        ModifierOption(
          id: 'o-salchicha',
          name: 'Salchicha americana',
          extraPrice: 5000,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: true,
          isReplacementEligible: false,
          isReplaceable: false,
          isEssential: true,
        ),
        ModifierOption(
          id: 'o-mozzarella',
          name: 'Queso mozzarella',
          extraPrice: 3500,
          isAvailable: false,
          isRemovable: true,
          includedByDefault: true,
        ),
        ModifierOption(
          id: 'o-huevo',
          name: 'Huevo de codorniz',
          extraPrice: 2500,
          isAvailable: true,
          isRemovable: true,
          includedByDefault: true,
        ),
        ModifierOption(
          id: 'o-tocineta',
          name: 'Tocineta crocante',
          extraPrice: 4000,
          isAvailable: true,
          isRemovable: true,
          includedByDefault: false,
        ),
      ],
    ),
    ModifierGroup(
      id: 'g-top',
      slug: 'toppings',
      name: 'Toppings',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-ripio',
          name: 'Papa ripio',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
    ModifierGroup(
      id: 'g-sau',
      slug: 'sauces',
      name: 'Salsas',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-ketchup',
          name: 'Ketchup',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
  ],
);

void main() {
  group('DetailSelections.fromCartItem', () {
    test('removed + reemplazo + extra + topping + salsa → los 5 sets', () {
      const item = CartItem(
        id: 'cart-1',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: [
          // Quitado directo.
          CartModifier(
            optionId: 'o-huevo',
            optionName: 'Huevo de codorniz',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
          // Reemplazo gratis: removed del agotado + added a 0 que lo
          // apunta con replacesOptionId — sin esa marca la fila added
          // se confundiría con un topping gratis.
          CartModifier(
            optionId: 'o-mozzarella',
            optionName: 'Queso mozzarella',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'o-tocineta',
            optionName: 'Tocineta crocante',
            action: CartModifierAction.added,
            priceDelta: 0,
            replacesOptionId: 'o-mozzarella',
          ),
          // Extra cobrado (doble salchicha — additionalOptions la
          // incluye por ser fija con precio).
          CartModifier(
            optionId: 'o-salchicha',
            optionName: 'Salchicha americana',
            action: CartModifierAction.added,
            priceDelta: 5000,
          ),
          // Topping y salsa gratis.
          CartModifier(
            optionId: 'o-ripio',
            optionName: 'Papa ripio',
            action: CartModifierAction.added,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'o-ketchup',
            optionName: 'Ketchup',
            action: CartModifierAction.added,
            priceDelta: 0,
          ),
        ],
      );

      final sel = DetailSelections.fromCartItem(item, _cachorro());

      // El agotado reemplazado vive SOLO en replacements — como en el
      // modo agregar; si además cayera en _removed, _buildModifiers
      // emitiría la fila `removed` duplicada al guardar (revisor-ui).
      expect(sel.removed, {'o-huevo'});
      expect(sel.replacements, {'o-mozzarella': 'o-tocineta'});
      // Doble salchicha (§045): extras es optionId → porciones.
      expect(sel.extras['o-salchicha'], 1);
      expect(sel.toppings, {'o-ripio'});
      expect(sel.sauces, {'o-ketchup'});
    });

    test('added con times N → extras conserva las porciones (§045)', () {
      const item = CartItem(
        id: 'cart-1',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: [
          // Doble tocineta — priceDelta ya es el total de línea.
          CartModifier(
            optionId: 'o-tocineta',
            optionName: 'Tocineta crocante',
            action: CartModifierAction.added,
            priceDelta: 8000,
            times: 2,
          ),
        ],
      );

      final sel = DetailSelections.fromCartItem(item, _cachorro());

      expect(sel.extras['o-tocineta'], 2);
    });

    test('added de una opción que ya no está en el producto → se descarta', () {
      const item = CartItem(
        id: 'cart-1',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: [
          // La piña salió de la carta tras agregar el ítem — la
          // edición no puede reconstruir lo que ya no existe.
          CartModifier(
            optionId: 'o-pina',
            optionName: 'Piña en trozos',
            action: CartModifierAction.added,
            priceDelta: 0,
          ),
        ],
      );

      final sel = DetailSelections.fromCartItem(item, _cachorro());

      expect(sel.extras, isEmpty);
      expect(sel.toppings, isEmpty);
      expect(sel.sauces, isEmpty);
      expect(sel.removed, isEmpty);
      expect(sel.replacements, isEmpty);
    });

    test('ítem tal cual → los 5 sets vacíos', () {
      const item = CartItem(
        id: 'cart-1',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: [],
      );

      final sel = DetailSelections.fromCartItem(item, _cachorro());

      expect(sel.removed, isEmpty);
      expect(sel.extras, isEmpty);
      expect(sel.toppings, isEmpty);
      expect(sel.sauces, isEmpty);
      expect(sel.replacements, isEmpty);
    });

    test('los sets son mutables — el detalle los alterna con _toggle', () {
      // Un `const {}` sería inmodificable en runtime; el contrato del
      // valor es que la pantalla agrega/quita ids libremente.
      final sel = DetailSelections();
      expect(() {
        sel.removed.add('x');
        sel.extras['x'] = 1;
        sel.toppings.add('x');
        sel.sauces.add('x');
        sel.replacements['a'] = 'b';
      }, returnsNormally);
    });
  });
}
