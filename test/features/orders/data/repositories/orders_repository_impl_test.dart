import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_service.dart';
import 'package:depredadog_app/features/orders/data/datasources/implementations/orders_remote_datasource_impl.dart';
import 'package:depredadog_app/features/orders/data/datasources/interfaces/i_orders_remote_datasource.dart';
import 'package:depredadog_app/features/orders/data/models/customer_order_model.dart';
import 'package:depredadog_app/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';

class MockRemoteDataSource extends Mock implements IOrdersRemoteDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

class MockNetworkService extends Mock implements INetworkService {}

/// JSON mínimo del OrderResponseDto (§015/016) para los fixtures.
Map<String, dynamic> orderJson({
  required String id,
  String status = 'pending',
  String serviceType = 'delivery',
  Map<String, dynamic>? payment = const {
    'method': 'transfer',
    'status': 'paid',
  },
  List<dynamic>? items,
}) => {
  'id': id,
  'serviceType': serviceType,
  'status': status,
  'items': items ?? const [],
  'payment': payment,
  'subtotal': 14000,
  'deliveryFee': 0,
  'createdAt': '2026-11-08T12:40:00.000Z',
  'deliveryAddress': 'Casa blanca frente a la cancha',
};

void main() {
  group('OrdersRepositoryImpl', () {
    late MockRemoteDataSource remote;
    late MockNetworkInfo networkInfo;
    late OrdersRepositoryImpl repository;

    final order = CustomerOrderModel.fromJson(orderJson(id: 'ord-1'));

    setUp(() {
      remote = MockRemoteDataSource();
      networkInfo = MockNetworkInfo();
      repository = OrdersRepositoryImpl(
        remoteDataSource: remote,
        networkInfo: networkInfo,
      );
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    });

    group('getActiveOrders', () {
      test('éxito → Right(items) del envelope bucket=active SIN '
          'page', () async {
        when(() => remote.fetchOrdersPage('active'))
            .thenAnswer((_) async => (items: [order], total: 1));

        final result = await repository.getActiveOrders();

        // Right compara la lista por identidad — se compara por
        // elementos (los modelos son Equatable).
        result.fold(
          (_) => fail('se esperaba Right con los pedidos activos'),
          (items) => expect(items, [order]),
        );
        verify(() => remote.fetchOrdersPage('active')).called(1);
        verifyNever(() => remote.fetchOrdersPage('history'));
      });

      test('sin conectividad → Left(Offline) y el datasource NUNCA '
          'se llama', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getActiveOrders();

        expect(
          result,
          const Left<OrdersFailure, List<CustomerOrder>>(
            OrdersOfflineFailure(),
          ),
        );
        verifyNever(() => remote.fetchOrdersPage(any()));
      });

      test('ServerException → OrdersServerFailure', () async {
        when(() => remote.fetchOrdersPage('active'))
            .thenThrow(const ServerException('boom', statusCode: 500));

        final result = await repository.getActiveOrders();

        expect(
          result,
          const Left<OrdersFailure, List<CustomerOrder>>(
            OrdersServerFailure('boom'),
          ),
        );
      });
    });

    group('getHistoryOrders', () {
      test('éxito → envelope items+total viaja como OrdersHistoryPage '
          'con el page pedido + limit explícito', () async {
        when(
          () => remote.fetchOrdersPage(
            'history',
            page: 2,
            limit: kOrdersHistoryPageSize,
          ),
        ).thenAnswer((_) async => (items: [order], total: 25));

        final result = await repository.getHistoryOrders(2);

        result.fold((_) => fail('esperaba Right'), (page) {
          expect(page.items, [order]);
          expect(page.total, 25);
        });
        verify(
          () => remote.fetchOrdersPage(
            'history',
            page: 2,
            limit: kOrdersHistoryPageSize,
          ),
        ).called(1);
      });

      test('sin conectividad → Left(Offline)', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getHistoryOrders(1);

        expect(
          result,
          const Left<OrdersFailure, OrdersHistoryPage>(OrdersOfflineFailure()),
        );
      });
    });

    group('getOrderDetail', () {
      test('éxito → Right(model) tal cual', () async {
        when(() => remote.fetchOrderDetail('ord-1'))
            .thenAnswer((_) async => order);

        final result = await repository.getOrderDetail('ord-1');

        expect(result, Right<OrdersFailure, CustomerOrder>(order));
        verify(() => remote.fetchOrderDetail('ord-1')).called(1);
      });

      test('NoConnectionException → OrdersOfflineFailure', () async {
        when(() => remote.fetchOrderDetail('ord-1'))
            .thenThrow(const NoConnectionException());

        final result = await repository.getOrderDetail('ord-1');

        expect(
          result,
          const Left<OrdersFailure, CustomerOrder>(OrdersOfflineFailure()),
        );
      });
    });

    group('cancelOrder', () {
      test('éxito → Right(orden cancelled del response)', () async {
        when(() => remote.cancelOrder('ord-1', 'Cancelado por el cliente'))
            .thenAnswer((_) async => order);

        final result = await repository.cancelOrder(
          'ord-1',
          'Cancelado por el cliente',
        );

        expect(result, Right<OrdersFailure, CustomerOrder>(order));
        verify(() => remote.cancelOrder('ord-1', 'Cancelado por el cliente'))
            .called(1);
      });

      test('409 con mensaje del servidor → OrdersCancelRejectedFailure '
          '(el motivo llega al toast tal cual)', () async {
        when(() => remote.cancelOrder(any(), any())).thenThrow(
          const ServerException('El pedido ya fue confirmado', statusCode: 409),
        );

        final result = await repository.cancelOrder('ord-1', 'x');

        expect(
          result,
          const Left<OrdersFailure, CustomerOrder>(
            OrdersCancelRejectedFailure('El pedido ya fue confirmado'),
          ),
        );
      });

      test('otro 4xx/5xx → OrdersServerFailure (no es rechazo de '
          'negocio)', () async {
        when(() => remote.cancelOrder(any(), any()))
            .thenThrow(const ServerException('boom', statusCode: 500));

        final result = await repository.cancelOrder('ord-1', 'x');

        expect(
          result,
          const Left<OrdersFailure, CustomerOrder>(OrdersServerFailure('boom')),
        );
      });

      test('sin conectividad → Left(Offline) sin llamar al '
          'datasource', () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.cancelOrder('ord-1', 'x');

        expect(
          result,
          const Left<OrdersFailure, CustomerOrder>(OrdersOfflineFailure()),
        );
        verifyNever(() => remote.cancelOrder(any(), any()));
      });
    });
  });

  group('OrdersRemoteDataSourceImpl', () {
    late MockNetworkService network;
    late OrdersRemoteDataSourceImpl dataSource;

    setUp(() {
      network = MockNetworkService();
      dataSource = OrdersRemoteDataSourceImpl(networkService: network);
    });

    test('fetchOrdersPage active → GET /orders?bucket=active sin page '
        '+ envelope {items,total} parseado', () async {
      when(() => network.get('/orders', queryParameters: {'bucket': 'active'}))
          .thenAnswer(
            (_) async => {
              'items': [orderJson(id: 'ord-1'), orderJson(id: 'ord-2')],
              'total': 2,
              'page': 1,
              'limit': 20,
            },
          );

      final res = await dataSource.fetchOrdersPage('active');

      expect(res.items, hasLength(2));
      expect(res.items.first.id, 'ord-1');
      expect(res.total, 2);
      verify(
        () => network.get('/orders', queryParameters: {'bucket': 'active'}),
      ).called(1);
    });

    test('fetchOrdersPage history → page viaja en queryParameters', () async {
      when(
        () => network.get(
          '/orders',
          queryParameters: {'bucket': 'history', 'page': 3},
        ),
      ).thenAnswer((_) async => {'items': const <dynamic>[], 'total': 45});

      final res = await dataSource.fetchOrdersPage('history', page: 3);

      expect(res.items, isEmpty);
      expect(res.total, 45);
      verify(
        () => network.get(
          '/orders',
          queryParameters: {'bucket': 'history', 'page': 3},
        ),
      ).called(1);
    });

    test('fetchOrderDetail → GET /orders/:id y mapea enums '
        '(pending→received, transfer→nequi, paid)', () async {
      when(() => network.get('/orders/ord-9'))
          .thenAnswer((_) async => orderJson(id: 'ord-9'));

      final order = await dataSource.fetchOrderDetail('ord-9');

      expect(order.status, OrderStatus.received);
      expect(order.paymentMethod, OrderPaymentMethod.nequi);
      expect(order.paymentStatus, OrderPaymentStatus.paid);
      expect(order.serviceType, OrderServiceType.delivery);
      verify(() => network.get('/orders/ord-9')).called(1);
    });

    test('payment:null → pending defensivo (pedidos viejos sin '
        'fila)', () async {
      when(() => network.get('/orders/ord-8'))
          .thenAnswer((_) async => orderJson(id: 'ord-8', payment: null));

      final order = await dataSource.fetchOrderDetail('ord-8');

      expect(order.paymentStatus, OrderPaymentStatus.pending);
      // Método por defecto nequi cuando no hay fila de payment.
      expect(order.paymentMethod, OrderPaymentMethod.nequi);
    });

    test('cancelOrder → POST /orders/:id/cancel con {reason} y '
        'parsea la orden cancelled (cash→onDelivery)', () async {
      when(
        () => network.post(
          '/orders/ord-5/cancel',
          body: {'reason': 'Cancelado por el cliente'},
        ),
      ).thenAnswer(
        (_) async => orderJson(
          id: 'ord-5',
          status: 'cancelled',
          payment: {'method': 'cash', 'status': 'failed'},
        ),
      );

      final order = await dataSource.cancelOrder(
        'ord-5',
        'Cancelado por el cliente',
      );

      expect(order.status, OrderStatus.cancelled);
      expect(order.paymentMethod, OrderPaymentMethod.onDelivery);
      expect(order.paymentStatus, OrderPaymentStatus.failed);
      verify(
        () => network.post(
          '/orders/ord-5/cancel',
          body: {'reason': 'Cancelado por el cliente'},
        ),
      ).called(1);
    });
  });
}
