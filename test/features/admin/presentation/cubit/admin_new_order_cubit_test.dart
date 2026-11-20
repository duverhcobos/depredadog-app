import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_new_order_draft.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_table.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_new_order_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_new_order_state.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/home/domain/failures/catalog_failure.dart';

import '../../fixtures/admin_new_order_fixtures.dart';

void main() {
  late FakeGetCatalogMenuUseCase menu;
  late FakeLoadAdminTablesUseCase tables;
  late FakeCreateAdminOrderUseCase create;
  late AdminNewOrderCubit cubit;

  /// Ítem del borrador — misma forma que el sheet produce.
  CartItem item({
    String productId = 'p-cachorro',
    List<CartModifier> modifiers = const [],
    int quantity = 1,
  }) => CartItem(
    id: '',
    productId: productId,
    productSlug: 'cachorro',
    productName: 'El Cachorro',
    unitBase: 14000,
    modifiers: modifiers,
    quantity: quantity,
  );

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
  );

  setUpAll(() {
    registerFallbackValue(
      const AdminNewOrderDraft(
        serviceType: AdminServiceType.dineIn,
        paymentMethod: AdminPaymentMethod.cash,
        items: [],
      ),
    );
  });

  setUp(() {
    menu = FakeGetCatalogMenuUseCase();
    tables = FakeLoadAdminTablesUseCase();
    create = FakeCreateAdminOrderUseCase();
    cubit = AdminNewOrderCubit(
      getMenu: menu,
      loadTables: tables,
      createOrder: create,
    );
    when(
      () => menu.call(),
    ).thenAnswer((_) async => Right(newOrderCategories()));
    when(
      () => tables.call(),
    ).thenAnswer((_) async => Right(newOrderTables()));
    when(() => create.call(any())).thenAnswer(
      (_) async => Right<AdminFailure, AdminOrder>(newOrderCreated()),
    );
  });

  tearDown(() => cubit.close());

  group('load — carta + mesas en paralelo (§042)', () {
    test('éxito: categorías + mesas pobladas, loading apagado', () async {
      await cubit.load();

      expect(cubit.state.categories, hasLength(2));
      expect(cubit.state.tables, hasLength(4));
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.failed, isFalse);
      verify(() => menu.call()).called(1);
      verify(() => tables.call()).called(1);
    });

    test('Left en CUALQUIERA de las dos piernas → failed (vista de '
        'error con Reintentar como la cola)', () async {
      when(
        () => tables.call(),
      ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

      await cubit.load();
      expect(cubit.state.failed, isTrue);
      expect(cubit.state.loading, isFalse);

      // La otra cara: carta cae, mesas sanas → también failed.
      when(
        () => tables.call(),
      ).thenAnswer((_) async => Right(newOrderTables()));
      when(() => menu.call()).thenAnswer(
        (_) async => const Left(CatalogOfflineFailure()),
      );
      await cubit.load();
      expect(cubit.state.failed, isTrue);
    });
  });

  group('borrador — items, mesa, servicio, pago (§042)', () {
    test('addItem: mismo producto + mismos mods MERGEA qty '
        '(sameConfiguration — la regla del carrito)', () {
      cubit.addItem(item(modifiers: const [sinCebolla]));
      cubit.addItem(item(modifiers: const [sinCebolla]));
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.items.single.quantity, 2);

      // Config distinta → fila aparte.
      cubit.addItem(item(modifiers: const [conTocineta]));
      expect(cubit.state.items, hasLength(2));
    });

    test('addItem respeta el tope 20 del DTO (merge clampeado)', () {
      cubit.addItem(item(quantity: 15));
      cubit.addItem(item(quantity: 10));
      expect(cubit.state.items.single.quantity, 20);
    });

    test('setItemQty: <=0 elimina la fila, >20 se clampea', () {
      cubit.addItem(item());
      final id = cubit.state.items.single.id;

      cubit.setItemQty(id, 3);
      expect(cubit.state.items.single.quantity, 3);

      cubit.setItemQty(id, 99);
      expect(cubit.state.items.single.quantity, 20);

      cubit.setItemQty(id, 0);
      expect(cubit.state.items, isEmpty);
    });

    test('removeItem saca solo la fila pedida', () {
      cubit.addItem(item());
      cubit.addItem(item(productId: 'p-papas'));
      final first = cubit.state.items.first.id;
      cubit.removeItem(first);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.items.single.productId, 'p-papas');
    });

    test('selectTable solo entra mesa LIBRE — ocupada e inactiva '
        'ignoradas aunque el tap llegara', () async {
      await cubit.load();
      cubit.selectTable('t-3'); // ocupada #7
      expect(cubit.state.selectedTableId, isNull);
      cubit.selectTable('t-4'); // inactiva
      expect(cubit.state.selectedTableId, isNull);
      cubit.selectTable('t-2'); // libre
      expect(cubit.state.selectedTableId, 't-2');
    });

    test('toggleService a pickup LIMPIA la mesa (tableId prohibido '
        'ahí) y volver a dineIn exige re-elegir', () async {
      await cubit.load();
      cubit.selectTable('t-2');
      cubit.toggleService(AdminServiceType.pickup);
      expect(cubit.state.serviceType, AdminServiceType.pickup);
      expect(cubit.state.selectedTableId, isNull);

      cubit.toggleService(AdminServiceType.dineIn);
      expect(cubit.state.selectedTableId, isNull);
    });

    test('goToCobro exige ítems — sin ticket no pasa de comanda', () {
      cubit.goToCobro();
      expect(cubit.state.step, AdminNewOrderStep.comanda);
      cubit.addItem(item());
      cubit.goToCobro();
      expect(cubit.state.step, AdminNewOrderStep.cobro);
      cubit.backToComanda();
      expect(cubit.state.step, AdminNewOrderStep.comanda);
    });
  });

  group('canSubmit — la puerta del "Crear pedido" (§042)', () {
    Future<void> seed() => cubit.load();

    test('dineIn SIN mesa no puede; con mesa libre sí', () async {
      await seed();
      cubit.addItem(item());
      expect(cubit.state.canSubmit, isFalse);
      cubit.selectTable('t-2');
      expect(cubit.state.canSubmit, isTrue);
    });

    test('pickup no pide mesa', () async {
      await seed();
      cubit.addItem(item());
      cubit.toggleService(AdminServiceType.pickup);
      expect(cubit.state.canSubmit, isTrue);
    });

    test('transfer exige celular 3xxxxxxxxx — cash no', () async {
      await seed();
      cubit.addItem(item());
      cubit.toggleService(AdminServiceType.pickup);
      cubit.setPayment(AdminPaymentMethod.transfer);
      expect(cubit.state.canSubmit, isFalse);

      cubit.setPayerPhone('123');
      expect(cubit.state.canSubmit, isFalse);
      cubit.setPayerPhone('3001234567');
      expect(cubit.state.canSubmit, isTrue);

      cubit.setPayment(AdminPaymentMethod.cash);
      cubit.setPayerPhone('');
      expect(cubit.state.canSubmit, isTrue);
    });

    test('mesa que quedó ocupada en el resync invalida sola '
        '(tableAvailable re-valida)', () async {
      await seed();
      cubit.addItem(item());
      cubit.selectTable('t-2');
      expect(cubit.state.canSubmit, isTrue);

      // El resync trae Mesa 2 ocupada — canSubmit cae solo.
      when(() => tables.call()).thenAnswer(
        (_) async => Right([
          for (final t in newOrderTables())
            t.id == 't-2'
                ? AdminTable(
                    id: t.id,
                    label: t.label,
                    isActive: t.isActive,
                    activeOrderNumber: 9,
                  )
                : t,
        ]),
      );
      await cubit.load();
      expect(cubit.state.canSubmit, isFalse);
    });
  });

  group('submit (§042)', () {
    Future<void> readyDraft() async {
      await cubit.load();
      cubit.addItem(item(modifiers: const [sinCebolla], quantity: 2));
      cubit.selectTable('t-2');
      cubit.setNotes('Mesa de la esquina');
    }

    test('éxito → la orden creada viaja y el draft sale completo '
        '(dineIn + mesa + ítems + nota)', () async {
      await readyDraft();
      final result = await cubit.submit();

      expect(result.order?.orderNumber, 8);
      expect(result.failure, isNull);
      final draft =
          verify(() => create.call(captureAny())).captured.single
              as AdminNewOrderDraft;
      expect(draft.serviceType, AdminServiceType.dineIn);
      expect(draft.tableId, 't-2');
      expect(draft.paymentMethod, AdminPaymentMethod.cash);
      expect(draft.payerPhone, isNull); // prohibido en cash
      expect(draft.items, hasLength(1));
      expect(draft.items.single.quantity, 2);
      expect(draft.notes, 'Mesa de la esquina');
    });

    test('transfer lleva payerPhone trimmeado en el draft', () async {
      await cubit.load();
      cubit.addItem(item());
      cubit.toggleService(AdminServiceType.pickup);
      cubit.setPayment(AdminPaymentMethod.transfer);
      cubit.setPayerPhone(' 3001234567');

      final result = await cubit.submit();

      expect(result.order, isNotNull);
      final draft =
          verify(() => create.call(captureAny())).captured.single
              as AdminNewOrderDraft;
      expect(draft.payerPhone, '3001234567');
      expect(draft.tableId, isNull); // prohibido en pickup
    });

    test('falla → (null, failure) con submitting liberado y la '
        'comanda se QUEDA', () async {
      await readyDraft();
      when(() => create.call(any())).thenAnswer(
        (_) async => const Left(
          AdminServerFailure(
            'Dispatch failed',
            errorCode: 'PAYMENT_DISPATCH_FAILED',
          ),
        ),
      );

      final result = await cubit.submit();

      expect(result.order, isNull);
      expect(result.failure, isA<AdminServerFailure>());
      expect(
        (result.failure! as AdminServerFailure).errorCode,
        'PAYMENT_DISPATCH_FAILED',
      );
      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.items, isNotEmpty); // el borrador sobrevive
    });

    test('TABLE_NOT_FOUND → resync de mesas en segundo plano '
        '(loadTables se re-pide solo)', () async {
      await readyDraft();
      clearInteractions(tables);
      when(() => create.call(any())).thenAnswer(
        (_) async => const Left(
          AdminServerFailure(
            'Table not found',
            errorCode: 'TABLE_NOT_FOUND',
          ),
        ),
      );
      when(
        () => tables.call(),
      ).thenAnswer((_) async => Right(newOrderTables()));

      final result = await cubit.submit();
      expect(result.failure, isA<AdminServerFailure>());

      // El resync corre en fire-and-forget — el microtask lo
      // completa antes de que el test lea el state.
      await Future<void>.delayed(Duration.zero);
      verify(() => tables.call()).called(1);
    });

    test('submit sin canSubmit es no-op — la puerta del CTA ya lo '
        'cubre (ni siquiera llama al use case)', () async {
      await cubit.load();
      // Sin ítems → canSubmit false.
      final result = await cubit.submit();
      expect(result.order, isNull);
      expect(result.failure, isNull);
      verifyNever(() => create.call(any()));
    });
  });
}
