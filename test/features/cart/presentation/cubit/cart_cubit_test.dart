import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_state.dart';

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

/// El Cachorro base $14.000 — sin personalización salvo que se pida.
void _addCachorro(CartCubit cubit, {List<CartModifier> modifiers = const []}) =>
    cubit.addItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: modifiers,
    );

void main() {
  group('CartCubit.addItem', () {
    blocTest<CartCubit, CartState>(
      'primera vez → 1 ítem qty 1 con id cart-1',
      build: CartCubit.new,
      act: _addCachorro,
      verify: (cubit) {
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.items.single.id, 'cart-1');
        expect(cubit.state.items.single.quantity, 1);
      },
    );

    blocTest<CartCubit, CartState>(
      'ids consecutivos cart-1, cart-2 entre filas distintas',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit);
        cubit.addItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          productName: 'La Trampa',
          unitBase: 18000,
          modifiers: const [],
        );
      },
      verify: (cubit) {
        expect(cubit.state.items.map((i) => i.id), ['cart-1', 'cart-2']);
      },
    );

    blocTest<CartCubit, CartState>(
      'misma configuración → qty 2 en la misma fila (merge)',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
        // Mismo producto + mismo modificador — en orden de lista
        // distinto para probar que la comparación ignora el orden.
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.items.single.quantity, 2);
      },
    );

    blocTest<CartCubit, CartState>(
      'configuración distinta → fila aparte (no merge)',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
        _addCachorro(cubit, modifiers: const [_extraTocineta]);
      },
      verify: (cubit) => expect(cubit.state.items, hasLength(2)),
    );
  });

  group('CartCubit.updateQuantity', () {
    blocTest<CartCubit, CartState>(
      'a 3 → qty 3 y subtotal recalculado',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_extraTocineta]);
        cubit.updateQuantity('cart-1', 3);
      },
      verify: (cubit) {
        expect(cubit.state.items.single.quantity, 3);
        // unitPrice = 14.000 + 4.000 = 18.000 → 3 × 18.000.
        expect(cubit.state.subtotal, 54000);
      },
    );

    blocTest<CartCubit, CartState>(
      'a 0 → elimina la fila (− en 1 quita el ítem)',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit);
        cubit.updateQuantity('cart-1', 0);
      },
      verify: (cubit) => expect(cubit.state.items, isEmpty),
    );
  });

  group('CartCubit.editItem', () {
    /// Resultado que devuelve editItem — la pantalla elige el toast
    /// con él ("Cambios guardados" vs "Se combinó con la fila igual").
    CartEditOutcome? outcome;

    blocTest<CartCubit, CartState>(
      'qty 1 sin cambio real de config → reemplaza en el mismo índice',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
        cubit.addItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          productName: 'La Trampa',
          unitBase: 18000,
          modifiers: const [],
        );
        // Misma config — solo refresca el snapshot includedNames:
        // el no-op en el mismo lugar (la fila no salta al final).
        cubit.editItem(
          itemId: 'cart-1',
          modifiers: const [_sinMozzarella],
          includedNames: const ['Pan artesanal'],
          applyToAll: true,
        );
      },
      verify: (cubit) {
        expect(cubit.state.items.map((i) => i.id), ['cart-1', 'cart-2']);
        final edited = cubit.state.items.first;
        expect(edited.modifiers, const [_sinMozzarella]);
        expect(edited.includedNames, const ['Pan artesanal']);
      },
    );

    blocTest<CartCubit, CartState>(
      'qty 2 applyToAll:true → la fila entera cambia de config',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
        _addCachorro(cubit, modifiers: const [_sinMozzarella]); // → qty 2
        cubit.editItem(
          itemId: 'cart-1',
          modifiers: const [_extraTocineta],
          includedNames: const ['Queso mozzarella'],
          applyToAll: true,
        );
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(1));
        final edited = cubit.state.items.single;
        expect(edited.quantity, 2);
        expect(edited.modifiers, const [_extraTocineta]);
        expect(edited.includedNames, const ['Queso mozzarella']);
      },
    );

    blocTest<CartCubit, CartState>(
      'qty 2 applyToAll:false → separa 1 y la fusiona con la fila igual',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]);
        _addCachorro(cubit, modifiers: const [_sinMozzarella]); // cart-1 qty 2
        // Fila destino con la MISMA config a la que se edita.
        _addCachorro(cubit, modifiers: const [_extraTocineta]); // cart-2
        outcome = cubit.editItem(
          itemId: 'cart-1',
          modifiers: const [_extraTocineta],
          includedNames: const ['Queso mozzarella'],
          applyToAll: false,
        );
      },
      verify: (cubit) {
        expect(outcome, CartEditOutcome.merged);
        // La original queda qty 1 en su índice con su config; la
        // unidad separada se suma a cart-2 (misma config) → qty 2.
        expect(cubit.state.items, hasLength(2));
        expect(cubit.state.items[0].id, 'cart-1');
        expect(cubit.state.items[0].quantity, 1);
        expect(cubit.state.items[0].modifiers, const [_sinMozzarella]);
        expect(cubit.state.items[1].id, 'cart-2');
        expect(cubit.state.items[1].quantity, 2);
        expect(cubit.state.items[1].modifiers, const [_extraTocineta]);
      },
    );

    blocTest<CartCubit, CartState>(
      'editar a config idéntica a otra fila → se fusionan sin duplicar',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit, modifiers: const [_sinMozzarella]); // cart-1
        _addCachorro(cubit, modifiers: const [_extraTocineta]); // cart-2
        outcome = cubit.editItem(
          itemId: 'cart-1',
          modifiers: const [_extraTocineta],
          includedNames: const ['Queso mozzarella'],
          applyToAll: true,
        );
      },
      verify: (cubit) {
        expect(outcome, CartEditOutcome.merged);
        // cart-1 desaparece absorbida por cart-2 (misma config) →
        // una sola fila con qty 2.
        expect(cubit.state.items, hasLength(1));
        final merged = cubit.state.items.single;
        expect(merged.id, 'cart-2');
        expect(merged.quantity, 2);
        expect(merged.modifiers, const [_extraTocineta]);
      },
    );
  });

  group('CartCubit.removeItem / clear', () {
    blocTest<CartCubit, CartState>(
      'removeItem quita solo esa fila',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit);
        cubit.addItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          productName: 'La Trampa',
          unitBase: 18000,
          modifiers: const [],
        );
        cubit.removeItem('cart-1');
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.items.single.id, 'cart-2');
      },
    );

    blocTest<CartCubit, CartState>(
      'clear vacía el carrito',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit);
        _addCachorro(cubit);
        cubit.clear();
      },
      verify: (cubit) {
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.isEmpty, isTrue);
      },
    );
  });

  group('CartState getters', () {
    blocTest<CartCubit, CartState>(
      'itemCount suma unidades (Σ quantity) — el badge del header',
      build: CartCubit.new,
      act: (cubit) {
        _addCachorro(cubit); // qty 1
        _addCachorro(cubit); // merge → qty 2
        cubit.addItem(
          productId: 'p-trampa',
          productSlug: 'trampa',
          productName: 'La Trampa',
          unitBase: 18000,
          modifiers: const [],
        ); // fila aparte qty 1
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(2));
        expect(cubit.state.itemCount, 3);
        // 2 × 14.000 + 1 × 18.000.
        expect(cubit.state.subtotal, 46000);
      },
    );
  });
}
