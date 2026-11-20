import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_service.dart';
import 'package:depredadog_app/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart';
import 'package:depredadog_app/features/admin/data/datasources/interfaces/i_admin_remote_datasource.dart';
import 'package:depredadog_app/features/admin/data/models/admin_day_close_model.dart';
import 'package:depredadog_app/features/admin/data/models/admin_order_model.dart';
import 'package:depredadog_app/features/admin/data/models/admin_table_model.dart';
import 'package:depredadog_app/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_new_order_draft.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockRemoteDataSource extends Mock implements IAdminRemoteDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockNetworkService extends Mock implements INetworkService {}

/// JSON mínimo del AdminOrderResponseDto (backend §019) para los
/// fixtures del datasource.
Map<String, dynamic> orderJson({
  required String id,
  String status = 'pending',
  String serviceType = 'delivery',
  String channel = 'online',
  Map<String, dynamic>? payment = const {
    'method': 'cash',
    'status': 'pending',
  },
  List<dynamic> items = const <dynamic>[],
}) => {
  'id': id,
  'orderNumber': 7,
  'channel': channel,
  'serviceType': serviceType,
  'status': status,
  'items': items,
  'payment': payment,
  'subtotal': 14000,
  'deliveryFee': 3000,
  'createdAt': '2026-11-08T17:40:00.000Z',
};

/// Ítem del DTO con sus modifiers (§039 — el detalle :id sí los trae,
/// el listado los omite a propósito).
Map<String, dynamic> itemJson({List<dynamic> modifiers = const <dynamic>[]}) => {
  'productId': 'p-depredador',
  'productSlug': 'depredador',
  'productName': 'El Depredador',
  'quantity': 1,
  'unitPrice': 25000,
  'includedNames': const ['Pan artesanal'],
  'modifiers': modifiers,
};

void main() {
  group('AdminRepositoryImpl', () {
    late MockRemoteDataSource remote;
    late MockNetworkInfo networkInfo;
    late AdminRepositoryImpl repository;

    final order = AdminOrderModel.fromJson(orderJson(id: 'ord-1'));

    setUp(() {
      remote = MockRemoteDataSource();
      networkInfo = MockNetworkInfo();
      repository = AdminRepositoryImpl(
        remoteDataSource: remote,
        networkInfo: networkInfo,
      );
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    group('getActiveOrders', () {
      test('éxito → Right(items) del envelope bucket=active SIN '
          'paginación', () async {
        when(() => remote.fetchQueuePage('active'))
            .thenAnswer((_) async => (items: [order], total: 1));

        final result = await repository.getActiveOrders();

        result.fold(
          (_) => fail('se esperaba Right con los pedidos activos'),
          (items) => expect(items, [order]),
        );
        verify(() => remote.fetchQueuePage('active')).called(1);
        verifyNever(() => remote.fetchQueuePage('history'));
      });

      test('sin conectividad → Left(AdminOfflineFailure) y el '
          'datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getActiveOrders();

        expect(
          result,
          const Left<AdminFailure, List<AdminOrder>>(AdminOfflineFailure()),
        );
        verifyNever(() => remote.fetchQueuePage(any()));
      });

      test('ServerException → AdminServerFailure con el mensaje', () async {
        when(() => remote.fetchQueuePage('active'))
            .thenThrow(const ServerException('boom', statusCode: 500));

        final result = await repository.getActiveOrders();

        expect(
          result,
          const Left<AdminFailure, List<AdminOrder>>(
            AdminServerFailure('boom'),
          ),
        );
      });

      test('NoConnectionException → AdminOfflineFailure', () async {
        when(() => remote.fetchQueuePage('active'))
            .thenThrow(const NoConnectionException());

        final result = await repository.getActiveOrders();

        expect(
          result,
          const Left<AdminFailure, List<AdminOrder>>(AdminOfflineFailure()),
        );
      });

      test('200 malformado (cast roto del datasource) → '
          'AdminServerFailure — sin el catch la UI quedaría '
          'cargando para siempre', () async {
        when(() => remote.fetchQueuePage('active'))
            .thenThrow(const FormatException('items missing'));

        final result = await repository.getActiveOrders();

        result.fold(
          (f) => expect(f, isA<AdminServerFailure>()),
          (_) => fail('se esperaba Left con AdminServerFailure'),
        );
      });
    });

    group('getHistoryOrders', () {
      test('éxito → envelope items+total viaja como AdminHistoryPage '
          'con el page pedido + limit explícito', () async {
        when(
          () => remote.fetchQueuePage(
            'history',
            page: 2,
            limit: kAdminHistoryPageSize,
          ),
        ).thenAnswer((_) async => (items: [order], total: 25));

        final result = await repository.getHistoryOrders(2);

        result.fold((_) => fail('esperaba Right'), (page) {
          expect(page.items, [order]);
          expect(page.total, 25);
        });
        verify(
          () => remote.fetchQueuePage(
            'history',
            page: 2,
            limit: kAdminHistoryPageSize,
          ),
        ).called(1);
      });

      test('sin conectividad → Left(AdminOfflineFailure)', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getHistoryOrders(1);

        expect(
          result,
          const Left<AdminFailure, AdminHistoryPage>(AdminOfflineFailure()),
        );
      });
    });

    group('getOrderDetail (§039)', () {
      test('éxito → Right(AdminOrder) del datasource — la comanda '
          'completa con modifiers viaja intacta', () async {
        when(
          () => remote.fetchAdminOrder('ord-1'),
        ).thenAnswer((_) async => order);

        final result = await repository.getOrderDetail('ord-1');

        result.fold(
          (_) => fail('se esperaba Right con la comanda'),
          (o) => expect(o, order),
        );
        verify(() => remote.fetchAdminOrder('ord-1')).called(1);
      });

      test('sin conectividad → Left(AdminOfflineFailure) y el '
          'datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getOrderDetail('ord-1');

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
        );
        verifyNever(() => remote.fetchAdminOrder(any()));
      });

      test('404 ORDER_NOT_FOUND (ServerException) → '
          'AdminServerFailure con el mensaje', () async {
        when(() => remote.fetchAdminOrder('ord-9')).thenThrow(
          const ServerException('ORDER_NOT_FOUND', statusCode: 404),
        );

        final result = await repository.getOrderDetail('ord-9');

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminServerFailure('ORDER_NOT_FOUND'),
          ),
        );
      });
    });

    group('updateOrderStatus (§040 — PATCH /admin/orders/:id/status)', () {
      test('éxito → Right(AdminOrder) del datasource con `to` y '
          '`cancelReason` reenviados intactos', () async {
        final moved = AdminOrderModel.fromJson(
          orderJson(id: 'ord-1', status: 'cancelled'),
        );
        when(
          () => remote.patchOrderStatus(
            'ord-1',
            to: 'cancelled',
            cancelReason: 'se acabó el pan',
          ),
        ).thenAnswer((_) async => moved);

        final result = await repository.updateOrderStatus(
          'ord-1',
          to: 'cancelled',
          cancelReason: 'se acabó el pan',
        );

        result.fold(
          (_) => fail('se esperaba Right con la orden actualizada'),
          (o) => expect(o, moved),
        );
        verify(
          () => remote.patchOrderStatus(
            'ord-1',
            to: 'cancelled',
            cancelReason: 'se acabó el pan',
          ),
        ).called(1);
      });

      test('409 INVALID_STATUS_TRANSITION → AdminConflictFailure con '
          'el errorCode viajando (la UI distingue conflicto vs. resto)',
          () async {
        when(
          () => remote.patchOrderStatus(
            'ord-1',
            to: 'confirmed',
            cancelReason: any(named: 'cancelReason'),
          ),
        ).thenThrow(
          const ServerException(
            'Invalid status transition',
            statusCode: 409,
            errorCode: 'INVALID_STATUS_TRANSITION',
          ),
        );

        final result = await repository.updateOrderStatus(
          'ord-1',
          to: 'confirmed',
        );

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminConflictFailure('INVALID_STATUS_TRANSITION'),
          ),
        );
      });

      test('409 PAYMENT_NOT_SETTLED → AdminConflictFailure — la '
          'otra cara del conflicto (ready→done exige PAID)', () async {
        when(
          () => remote.patchOrderStatus(
            'ord-1',
            to: 'done',
            cancelReason: any(named: 'cancelReason'),
          ),
        ).thenThrow(
          const ServerException(
            'Payment not settled',
            statusCode: 409,
            errorCode: 'PAYMENT_NOT_SETTLED',
          ),
        );

        final result = await repository.updateOrderStatus(
          'ord-1',
          to: 'done',
        );

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminConflictFailure('PAYMENT_NOT_SETTLED'),
          ),
        );
      });

      test('404 → AdminServerFailure (no es conflicto — el pedido no '
          'existe, no una carrera perdida)', () async {
        when(
          () => remote.patchOrderStatus(
            'ord-9',
            to: 'confirmed',
            cancelReason: any(named: 'cancelReason'),
          ),
        ).thenThrow(
          const ServerException('ORDER_NOT_FOUND', statusCode: 404),
        );

        final result = await repository.updateOrderStatus(
          'ord-9',
          to: 'confirmed',
        );

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminServerFailure('ORDER_NOT_FOUND'),
          ),
        );
      });

      test('sin conectividad → Left(AdminOfflineFailure) y el '
          'datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.updateOrderStatus(
          'ord-1',
          to: 'confirmed',
        );

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
        );
        verifyNever(
          () => remote.patchOrderStatus(
            any(),
            to: any(named: 'to'),
            cancelReason: any(named: 'cancelReason'),
          ),
        );
      });
    });

    group('confirmOrderPayment (§041 — POST '
        '/admin/orders/:id/confirm-payment)', () {
      test('éxito → Right(AdminOrder) del datasource — la orden '
          'cobrada y avanzada en el mismo hecho viaja intacta', () async {
        final paid = AdminOrderModel.fromJson(
          orderJson(id: 'ord-1', status: 'done'),
        );
        when(
          () => remote.confirmPayment('ord-1'),
        ).thenAnswer((_) async => paid);

        final result = await repository.confirmOrderPayment('ord-1');

        result.fold(
          (_) => fail('se esperaba Right con la orden cobrada'),
          (o) => expect(o, paid),
        );
        verify(() => remote.confirmPayment('ord-1')).called(1);
      });

      test('409 PAYMENT_NOT_CONFIRMABLE → AdminConflictFailure con '
          'el errorCode viajando (la UI muestra "el pedido ya '
          'cambió")', () async {
        when(() => remote.confirmPayment('ord-1')).thenThrow(
          const ServerException(
            'Payment cannot be confirmed',
            statusCode: 409,
            errorCode: 'PAYMENT_NOT_CONFIRMABLE',
          ),
        );

        final result = await repository.confirmOrderPayment('ord-1');

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminConflictFailure('PAYMENT_NOT_CONFIRMABLE'),
          ),
        );
      });

      test('sin conectividad → Left(AdminOfflineFailure) y el '
          'datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.confirmOrderPayment('ord-1');

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
        );
        verifyNever(() => remote.confirmPayment(any()));
      });
    });

    group('day-close (§041 — GET/POST /admin/day-close)', () {
      final snapshot = AdminDayCloseModel.fromJson(
        const {
          'orderCount': 2,
          'totalAmount': 44000,
          'byMethod': [
            {'method': 'cash', 'count': 1, 'amount': 28000},
          ],
          'cancelledCount': 1,
          'cancelledAmount': 16000,
        },
      );

      test('getDayClosePreview éxito → Right(snapshot) del '
          'datasource', () async {
        when(
          () => remote.fetchDayClose(),
        ).thenAnswer((_) async => snapshot);

        final result = await repository.getDayClosePreview();

        result.fold(
          (_) => fail('se esperaba Right con el preview'),
          (s) => expect(s, snapshot),
        );
        verify(() => remote.fetchDayClose()).called(1);
      });

      test('closeDay éxito → Right(snapshot persistido) del '
          'datasource', () async {
        when(
          () => remote.postDayClose(),
        ).thenAnswer((_) async => snapshot);

        final result = await repository.closeDay();

        result.fold(
          (_) => fail('se esperaba Right con el cierre'),
          (s) => expect(s, snapshot),
        );
        verify(() => remote.postDayClose()).called(1);
      });

      test('sin conectividad → Left(AdminOfflineFailure) en AMBOS y '
          'el datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final preview = await repository.getDayClosePreview();
        final closed = await repository.closeDay();

        expect(
          preview,
          const Left<AdminFailure, AdminDayClose>(AdminOfflineFailure()),
        );
        expect(
          closed,
          const Left<AdminFailure, AdminDayClose>(AdminOfflineFailure()),
        );
        verifyNever(() => remote.fetchDayClose());
        verifyNever(() => remote.postDayClose());
      });
    });

    group('getTables + createInPersonOrder (§042)', () {
      /// Borrador dine_in con un ítem personalizado: removed
      /// cebolla + added tocineta cobrada + added piña (salsa) —
      /// cubre las dos acciones y el replacesOptionId nullable.
      AdminNewOrderDraft dineInDraft() => AdminNewOrderDraft(
        serviceType: AdminServiceType.dineIn,
        tableId: 't-2',
        paymentMethod: AdminPaymentMethod.cash,
        notes: '  Mesa de la esquina  ',
        items: const [
          CartItem(
            id: 'comanda-1',
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            productName: 'El Cachorro',
            unitBase: 14000,
            quantity: 2,
            modifiers: [
              CartModifier(
                optionId: 'o-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
                group: CartModifierGroup.ingredient,
              ),
              CartModifier(
                optionId: 'o-tocineta',
                optionName: 'Tocineta crocante',
                action: CartModifierAction.added,
                priceDelta: 4000,
                group: CartModifierGroup.extra,
              ),
              CartModifier(
                optionId: 'o-pina',
                optionName: 'Piña',
                action: CartModifierAction.added,
                priceDelta: 0,
                replacesOptionId: 'o-cebolla',
                group: CartModifierGroup.sauce,
              ),
            ],
          ),
        ],
      );

      test('getTables éxito → Right(List<AdminTable>) del '
          'datasource', () async {
        // El datasource resuelve MODELS (parse del JSON) — el repo
        // los deja pasar como entidades AdminTable.
        final tables = [
          AdminTableModel.fromJson(const {
            'id': 't-1',
            'label': 'Mesa 1',
            'isActive': true,
            'activeOrderNumber': null,
          }),
          AdminTableModel.fromJson(const {
            'id': 't-3',
            'label': 'Mesa 3',
            'isActive': true,
            'activeOrderNumber': 7,
          }),
        ];
        when(
          () => remote.fetchTables(),
        ).thenAnswer((_) async => tables);

        final result = await repository.getTables();

        result.fold(
          (_) => fail('se esperaba Right con las mesas'),
          (ts) => expect(ts, tables),
        );
        verify(() => remote.fetchTables()).called(1);
      });

      test('payload dine_in EXACTO: serviceType, tableId, items con '
          'modifiers (optionId+action+replacesOptionId solo cuando '
          'viaja), cash SIN payerPhone y notes trimmeadas', () async {
        final order = AdminOrderModel.fromJson(
          orderJson(id: 'ord-nueva', serviceType: 'dine_in'),
        );
        when(() => remote.createOrder(any())).thenAnswer((_) async => order);

        final result = await repository.createInPersonOrder(dineInDraft());

        result.fold(
          (_) => fail('se esperaba Right con la orden creada'),
          (o) => expect(o.id, 'ord-nueva'),
        );
        final captured = verify(
          () => remote.createOrder(captureAny()),
        ).captured.single as Map<String, dynamic>;
        expect(captured, {
          'serviceType': 'dine_in',
          'tableId': 't-2',
          'items': [
            {
              'productId': 'p-cachorro',
              'quantity': 2,
              'modifiers': [
                {'optionId': 'o-cebolla', 'action': 'removed'},
                {'optionId': 'o-tocineta', 'action': 'added'},
                {
                  'optionId': 'o-pina',
                  'action': 'added',
                  'replacesOptionId': 'o-cebolla',
                },
              ],
            },
          ],
          'paymentMethod': 'cash',
          'notes': 'Mesa de la esquina',
        });
      });

      test('payload pickup + transfer: serviceType pickup SIN '
          'tableId, payerPhone viaja y la nota vacía se omite', () async {
        final order = AdminOrderModel.fromJson(
          orderJson(id: 'ord-p', serviceType: 'pickup'),
        );
        when(() => remote.createOrder(any())).thenAnswer((_) async => order);

        await repository.createInPersonOrder(
          const AdminNewOrderDraft(
            serviceType: AdminServiceType.pickup,
            paymentMethod: AdminPaymentMethod.transfer,
            payerPhone: '3001234567',
            notes: '   ',
            items: [
              CartItem(
                id: 'comanda-1',
                productId: 'p-papas',
                productSlug: 'manada-papas',
                productName: 'Manada de papas',
                unitBase: 10000,
                modifiers: [],
              ),
            ],
          ),
        );

        final captured = verify(
          () => remote.createOrder(captureAny()),
        ).captured.single as Map<String, dynamic>;
        expect(captured, {
          'serviceType': 'pickup',
          'items': [
            {
              'productId': 'p-papas',
              'quantity': 1,
              'modifiers': <dynamic>[],
            },
          ],
          'paymentMethod': 'transfer',
          'payerPhone': '3001234567',
        });
        expect(captured.containsKey('tableId'), isFalse);
        expect(captured.containsKey('notes'), isFalse);
      });

      test('404 TABLE_NOT_FOUND → AdminServerFailure CON errorCode '
          '(la comanda resincroniza mesas y tosteea "la mesa '
          'cambió")', () async {
        when(() => remote.createOrder(any())).thenThrow(
          const ServerException(
            'Table not found',
            statusCode: 404,
            errorCode: 'TABLE_NOT_FOUND',
          ),
        );

        final result = await repository.createInPersonOrder(dineInDraft());

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminServerFailure(
              'Table not found',
              errorCode: 'TABLE_NOT_FOUND',
            ),
          ),
        );
      });

      test('409 ORDER_CATALOG_VIOLATION → AdminConflictFailure con '
          'el código (un ítem se agotó entre el load y el POST)', () async {
        when(() => remote.createOrder(any())).thenThrow(
          const ServerException(
            'Catalog violation',
            statusCode: 409,
            errorCode: 'ORDER_CATALOG_VIOLATION',
          ),
        );

        final result = await repository.createInPersonOrder(dineInDraft());

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminConflictFailure('ORDER_CATALOG_VIOLATION'),
          ),
        );
      });

      test('502 PAYMENT_DISPATCH_FAILED → AdminServerFailure CON '
          'errorCode (el push transfer no salió)', () async {
        when(() => remote.createOrder(any())).thenThrow(
          const ServerException(
            'Dispatch failed',
            statusCode: 502,
            errorCode: 'PAYMENT_DISPATCH_FAILED',
          ),
        );

        final result = await repository.createInPersonOrder(dineInDraft());

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(
            AdminServerFailure(
              'Dispatch failed',
              errorCode: 'PAYMENT_DISPATCH_FAILED',
            ),
          ),
        );
      });

      test('sin conectividad → Left(AdminOfflineFailure) y el '
          'datasource NUNCA se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.createInPersonOrder(dineInDraft());

        expect(
          result,
          const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
        );
        verifyNever(() => remote.createOrder(any()));
        verifyNever(() => remote.fetchTables());
      });
    });
  });

  group('AdminRemoteDataSourceImpl', () {
    late MockNetworkService network;
    late AdminRemoteDataSourceImpl dataSource;

    setUp(() {
      network = MockNetworkService();
      dataSource = AdminRemoteDataSourceImpl(networkService: network);
    });

    test('fetchQueuePage active → GET /admin/orders?bucket=active '
        'sin page + envelope {items,total} parseado', () async {
      when(
        () => network.get('/admin/orders', queryParameters: {'bucket': 'active'}),
      ).thenAnswer(
        (_) async => {
          'items': [orderJson(id: 'ord-1'), orderJson(id: 'ord-2')],
          'total': 2,
          'page': 1,
          'limit': 20,
        },
      );

      final res = await dataSource.fetchQueuePage('active');

      expect(res.items, hasLength(2));
      expect(res.items.first.id, 'ord-1');
      expect(res.items.first.orderNumber, 7);
      expect(res.items.first.status, OrderStatus.received);
      expect(res.total, 2);
      verify(
        () => network.get(
          '/admin/orders',
          queryParameters: {'bucket': 'active'},
        ),
      ).called(1);
    });

    test('fetchQueuePage history → page + limit viajan en '
        'queryParameters', () async {
      when(
        () => network.get(
          '/admin/orders',
          queryParameters: {'bucket': 'history', 'page': 3, 'limit': 20},
        ),
      ).thenAnswer((_) async => {'items': const <dynamic>[], 'total': 45});

      final res = await dataSource.fetchQueuePage(
        'history',
        page: 3,
        limit: 20,
      );

      expect(res.items, isEmpty);
      expect(res.total, 45);
      verify(
        () => network.get(
          '/admin/orders',
          queryParameters: {'bucket': 'history', 'page': 3, 'limit': 20},
        ),
      ).called(1);
    });

    test('fetchAdminOrder → GET /admin/orders/:id — mismo DTO del '
        'listado pero con los modifiers poblados (§039)', () async {
      when(() => network.get('/admin/orders/ord-1')).thenAnswer(
        (_) async => orderJson(
          id: 'ord-1',
          items: [
            itemJson(
              modifiers: [
                {
                  'optionId': 'ing-cebolla',
                  'optionName': 'Cebolla',
                  'action': 'removed',
                  'priceDelta': 0,
                },
                {
                  'optionId': 'ex-queso',
                  'optionName': 'Queso cheddar',
                  'action': 'added',
                  'priceDelta': 2500,
                  'modifierGroup': 'extras',
                },
              ],
            ),
          ],
        ),
      );

      final res = await dataSource.fetchAdminOrder('ord-1');

      expect(res.id, 'ord-1');
      expect(res.items, hasLength(1));
      expect(res.items.single.modifiers, hasLength(2));
      expect(
        res.items.single.modifiers.first.action,
        CartModifierAction.removed,
      );
      expect(res.items.single.modifiers.last.priceDelta, 2500);
      verify(() => network.get('/admin/orders/ord-1')).called(1);
    });

    test('patchOrderStatus → PATCH /admin/orders/:id/status con el '
        '`to` pedido — sin cancelReason cuando no viaja (§040)', () async {
      when(
        () => network.patch(
          '/admin/orders/ord-1/status',
          body: {'to': 'confirmed'},
        ),
      ).thenAnswer((_) async => orderJson(id: 'ord-1', status: 'confirmed'));

      final res = await dataSource.patchOrderStatus('ord-1', to: 'confirmed');

      expect(res.status, OrderStatus.confirmed);
      verify(
        () => network.patch(
          '/admin/orders/ord-1/status',
          body: {'to': 'confirmed'},
        ),
      ).called(1);
    });

    test('patchOrderStatus con motivo → cancelReason viaja en el '
        'body solo cuando viene (cancel con razón)', () async {
      when(
        () => network.patch(
          '/admin/orders/ord-1/status',
          body: {'to': 'cancelled', 'cancelReason': 'se acabó el pan'},
        ),
      ).thenAnswer(
        (_) async => orderJson(
          id: 'ord-1',
          status: 'cancelled',
        ),
      );

      final res = await dataSource.patchOrderStatus(
        'ord-1',
        to: 'cancelled',
        cancelReason: 'se acabó el pan',
      );

      expect(res.status, OrderStatus.cancelled);
      verify(
        () => network.patch(
          '/admin/orders/ord-1/status',
          body: {'to': 'cancelled', 'cancelReason': 'se acabó el pan'},
        ),
      ).called(1);
    });

    test('patchOrderStatus parsea la vista admin completa del 200 — '
        'statusChangedAt re-sellado llega al entity', () async {
      when(
        () => network.patch(
          '/admin/orders/ord-1/status',
          body: {'to': 'preparing'},
        ),
      ).thenAnswer(
        (_) async => {
          ...orderJson(id: 'ord-1', status: 'preparing'),
          'statusChangedAt': '2026-11-08T17:55:00.000Z',
        },
      );

      final res = await dataSource.patchOrderStatus('ord-1', to: 'preparing');

      expect(res.status, OrderStatus.preparing);
      expect(res.statusChangedAt, isNotNull);
      expect(res.orderNumber, 7);
    });
  });
}
