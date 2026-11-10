import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/cancel_order_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/get_order_detail_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_more_history_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_orders_use_case.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_state.dart';

class MockLoadOrders extends Mock implements LoadOrdersUseCase {}

class MockLoadMoreHistory extends Mock implements LoadMoreHistoryUseCase {}

class MockGetOrderDetail extends Mock implements GetOrderDetailUseCase {}

class MockCancelOrder extends Mock implements CancelOrderUseCase {}

CustomerOrder _order({
  required String id,
  OrderStatus status = OrderStatus.received,
  OrderServiceType serviceType = OrderServiceType.delivery,
  OrderPaymentMethod paymentMethod = OrderPaymentMethod.nequi,
  OrderPaymentStatus paymentStatus = OrderPaymentStatus.pending,
  int subtotal = 14000,
  int deliveryFee = 0,
  String? cancelReason,
}) => CustomerOrder(
  id: id,
  serviceType: serviceType,
  status: status,
  items: const [
    OrderItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      name: 'El Cachorro',
      quantity: 1,
      unitPrice: 14000,
    ),
  ],
  paymentMethod: paymentMethod,
  paymentStatus: paymentStatus,
  subtotal: subtotal,
  deliveryFee: deliveryFee,
  placedAt: DateTime(2026, 11, 8, 12, 40),
  cancelReason: cancelReason,
);

final _activeReceived = _order(id: 'ord-2');
final _activePreparing = _order(id: 'ord-1', status: OrderStatus.preparing);
final _done = _order(id: 'ord-3', status: OrderStatus.done);
final _cancelled = _order(
  id: 'ord-2',
  status: OrderStatus.cancelled,
  cancelReason: 'Cancelado por el cliente',
);

void main() {
  late MockLoadOrders loadOrders;
  late MockLoadMoreHistory loadMore;
  late MockGetOrderDetail getDetail;
  late MockCancelOrder cancelOrder;
  late OrdersDataResult loadResult;

  OrdersCubit buildCubit() => OrdersCubit(
    loadOrdersUseCase: loadOrders,
    loadMoreHistoryUseCase: loadMore,
    getOrderDetailUseCase: getDetail,
    cancelOrderUseCase: cancelOrder,
  );

  setUp(() {
    loadOrders = MockLoadOrders();
    loadMore = MockLoadMoreHistory();
    getDetail = MockGetOrderDetail();
    cancelOrder = MockCancelOrder();
    loadResult = OrdersDataResult(
      active: Right([_activePreparing, _activeReceived]),
      history: Right(OrdersHistoryPage(items: [_done], total: 1)),
    );
    when(() => loadOrders.call()).thenAnswer((_) async => loadResult);
    when(() => loadMore.call(any())).thenAnswer(
      (_) async => Right(OrdersHistoryPage(items: [_done], total: 1)),
    );
    when(() => getDetail.call(any()))
        .thenAnswer((_) async => Right(_activeReceived));
    when(() => cancelOrder.call(any(), any()))
        .thenAnswer((_) async => Right(_cancelled));
  });

  group('estado inicial (§027 — sin mocks, dataLoading espera el '
      'primer loadOrders)', () {
    test('vacío + dataLoading:true + flags en false', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.dataLoading, isTrue);
      expect(cubit.state.activeFailed, isFalse);
      expect(cubit.state.historyFailed, isFalse);
      expect(cubit.state.historyTotal, 0);
      expect(cubit.state.historyHasMore, isFalse);
    });
  });

  group('loadOrders (§027 — fan-out que degrada por pierna)', () {
    blocTest<OrdersCubit, OrdersState>(
      'load ok → activos + historial poblados, dataLoading:false',
      build: buildCubit,
      act: (cubit) => cubit.loadOrders(),
      verify: (cubit) {
        expect(cubit.state.active.map((o) => o.id), ['ord-1', 'ord-2']);
        expect(cubit.state.history.single.id, 'ord-3');
        expect(cubit.state.historyTotal, 1);
        expect(cubit.state.dataLoading, isFalse);
        expect(cubit.state.activeFailed, isFalse);
        expect(cubit.state.historyFailed, isFalse);
      },
    );

    test('activos falla → activeFailed + lista vacía; el historial '
        'llega igual (una pierna no tumba la otra)', () async {
      loadResult = OrdersDataResult(
        active: const Left(OrdersOfflineFailure()),
        history: Right(OrdersHistoryPage(items: [_done], total: 1)),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadOrders();

      expect(cubit.state.activeFailed, isTrue);
      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, hasLength(1));
      expect(cubit.state.historyFailed, isFalse);
      expect(cubit.state.dataLoading, isFalse);
    });

    test('historial falla → historyFailed + total 0; los activos '
        'llegan igual', () async {
      loadResult = OrdersDataResult(
        active: Right([_activeReceived]),
        history: const Left(OrdersServerFailure('boom')),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadOrders();

      expect(cubit.state.historyFailed, isTrue);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.historyTotal, 0);
      expect(cubit.state.active.single.id, 'ord-2');
      expect(cubit.state.activeFailed, isFalse);
    });

    test('retry limpia los flags y recupera (es también el '
        'pull-to-refresh y el reload al entrar al tab)', () async {
      loadResult = const OrdersDataResult(
        active: Left(OrdersOfflineFailure()),
        history: Left(OrdersOfflineFailure()),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadOrders();
      expect(cubit.state.activeFailed, isTrue);
      expect(cubit.state.historyFailed, isTrue);

      loadResult = OrdersDataResult(
        active: Right([_activeReceived]),
        history: Right(OrdersHistoryPage(items: [_done], total: 1)),
      );
      await cubit.loadOrders();
      expect(cubit.state.activeFailed, isFalse);
      expect(cubit.state.historyFailed, isFalse);
      expect(cubit.state.active, hasLength(1));
      expect(cubit.state.history, hasLength(1));
    });
  });

  group('loadMoreHistory (§027 — "Cargar más" del historial)', () {
    /// Historial con 20 ítems (una página llena) → hasMore.
    List<CustomerOrder> pageOf(int n, {int from = 0}) => [
      for (var i = 0; i < n; i++)
        _order(id: 'ord-${from + i}', status: OrderStatus.done),
    ];

    test('éxito → acumula la página y actualiza el total', () async {
      loadResult = OrdersDataResult(
        active: Right([_activeReceived]),
        history: Right(OrdersHistoryPage(items: pageOf(20), total: 25)),
      );
      final page2 = pageOf(5, from: 20);
      when(() => loadMore.call(any())).thenAnswer(
        (_) async => Right(OrdersHistoryPage(items: page2, total: 25)),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();
      expect(cubit.state.historyHasMore, isTrue);

      await cubit.loadMoreHistory();

      // page = 20 ~/ 20 + 1 = 2.
      verify(() => loadMore.call(2)).called(1);
      expect(cubit.state.history, hasLength(25));
      expect(cubit.state.historyTotal, 25);
      expect(cubit.state.historyLoadingMore, isFalse);
      // Tope alcanzado: ya no hay "Cargar más".
      expect(cubit.state.historyHasMore, isFalse);
    });

    test('falla → historyLoadMoreFailed conserva lo ya cargado y el '
        'retry repite la MISMA página', () async {
      loadResult = OrdersDataResult(
        active: Right([_activeReceived]),
        history: Right(OrdersHistoryPage(items: pageOf(20), total: 25)),
      );
      when(() => loadMore.call(any()))
          .thenAnswer((_) async => const Left(OrdersOfflineFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      await cubit.loadMoreHistory();
      expect(cubit.state.historyLoadMoreFailed, isTrue);
      expect(cubit.state.history, hasLength(20));

      // Retry en la misma fila: vuelve a pedir page 2 y acumula.
      final page2 = pageOf(5, from: 20);
      when(() => loadMore.call(any())).thenAnswer(
        (_) async => Right(OrdersHistoryPage(items: page2, total: 25)),
      );
      await cubit.loadMoreHistory();
      verify(() => loadMore.call(2)).called(2);
      expect(cubit.state.historyLoadMoreFailed, isFalse);
      expect(cubit.state.history, hasLength(25));
    });

    test('doble-tap mientras viaja → una sola llamada al use-case', () async {
      loadResult = OrdersDataResult(
        active: Right([_activeReceived]),
        history: Right(OrdersHistoryPage(items: pageOf(20), total: 25)),
      );
      final completer = Completer<Either<OrdersFailure, OrdersHistoryPage>>();
      when(() => loadMore.call(any())).thenAnswer((_) => completer.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      final first = cubit.loadMoreHistory();
      final second = cubit.loadMoreHistory(); // guardado: no compite.
      completer.complete(
        Right(OrdersHistoryPage(items: pageOf(5, from: 20), total: 25)),
      );
      await Future.wait([first, second]);

      verify(() => loadMore.call(any())).called(1);
    });
  });

  group('refreshOrder (§027 — GET /orders/:id al abrir el detalle)', () {
    test('activo con estado nuevo → reemplaza en la MISMA posición', () async {
      final confirmed = _order(id: 'ord-1', status: OrderStatus.confirmed);
      when(() => getDetail.call('ord-1'))
          .thenAnswer((_) async => Right(confirmed));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      await cubit.refreshOrder('ord-1');

      expect(cubit.state.active, hasLength(2));
      expect(cubit.state.active.first.id, 'ord-1');
      expect(cubit.state.active.first.status, OrderStatus.confirmed);
    });

    test('activo que pasó a terminal server-side → migra al frente '
        'del historial (la cancelada por el admin cambia de bucket)', () async {
      final doneNow = _order(id: 'ord-1', status: OrderStatus.done);
      when(() => getDetail.call('ord-1'))
          .thenAnswer((_) async => Right(doneNow));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      await cubit.refreshOrder('ord-1');

      expect(cubit.state.active.map((o) => o.id), ['ord-2']);
      expect(cubit.state.history.first.id, 'ord-1');
      expect(cubit.state.history.first.status, OrderStatus.done);
      expect(cubit.state.history, hasLength(2));
    });

    test('pedido del historial → reemplaza su fila en el bucket', () async {
      final cancelledNow = _order(
        id: 'ord-3',
        status: OrderStatus.cancelled,
        cancelReason: 'Cancelado por el local',
      );
      when(() => getDetail.call('ord-3'))
          .thenAnswer((_) async => Right(cancelledNow));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      await cubit.refreshOrder('ord-3');

      expect(cubit.state.history.single.id, 'ord-3');
      expect(cubit.state.history.single.status, OrderStatus.cancelled);
    });

    test('falla → silenciosa: el snapshot del listado queda intacto', () async {
      when(() => getDetail.call(any()))
          .thenAnswer((_) async => const Left(OrdersServerFailure('boom')));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();
      final before = cubit.state;

      await cubit.refreshOrder('ord-1');

      expect(cubit.state, before);
    });
  });

  group('cancelOrder (§027 — POST /orders/:id/cancel)', () {
    test('éxito → devuelve null y la entidad del response migra al '
        'frente del historial', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      final error = await cubit.cancelOrder('ord-2');

      expect(error, isNull);
      verify(() => cancelOrder.call('ord-2', 'Cancelado por el cliente'))
          .called(1);
      expect(cubit.state.active.map((o) => o.id), ['ord-1']);
      expect(cubit.state.history.first.id, 'ord-2');
      expect(cubit.state.history.first.status, OrderStatus.cancelled);
      expect(
        cubit.state.history.first.cancelReason,
        'Cancelado por el cliente',
      );
    });

    test('409 → devuelve la OrdersCancelRejectedFailure (la UI la '
        'traduce — el message inglés del servidor no se muestra) + '
        'dispara loadOrders silencioso de resincronización', () async {
      when(() => cancelOrder.call(any(), any())).thenAnswer(
        (_) async => const Left(
          OrdersCancelRejectedFailure(
            'Order can only be cancelled while pending',
          ),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      final failure = await cubit.cancelOrder('ord-2');
      // El resync es fire-and-forget — un tick para que se registre.
      await Future<void>.delayed(Duration.zero);

      expect(failure, isA<OrdersCancelRejectedFailure>());
      // called(2) = carga inicial + resincronización post-falla.
      // (Un verify intermedio consumiría la invocación verificada
      // y la cuenta quedaría en 1 aunque el resync sí haya corrido.)
      verify(() => loadOrders.call()).called(2);
    });

    test('offline/otra falla → devuelve la failure (genérico l10n en '
        'la UI) y también resincroniza', () async {
      when(() => cancelOrder.call(any(), any()))
          .thenAnswer((_) async => const Left(OrdersOfflineFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadOrders();

      final failure = await cubit.cancelOrder('ord-2');
      await Future<void>.delayed(Duration.zero);

      expect(failure, isA<OrdersOfflineFailure>());
      verify(() => loadOrders.call()).called(2);
    });
  });
}
