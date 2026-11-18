import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_service.dart';
import 'package:depredadog_app/features/admin/data/datasources/implementations/admin_remote_datasource_impl.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockNetworkService extends Mock implements INetworkService {}

/// JSON mínimo del AdminOrderResponseDto (backend §019) — mismo
/// helper del test del repository.
Map<String, dynamic> orderJson({
  required String id,
  String status = 'pending',
  String serviceType = 'dine_in',
  String channel = 'presencial',
  Map<String, dynamic>? payment = const {
    'method': 'cash',
    'status': 'pending',
  },
}) => {
  'id': id,
  'orderNumber': 7,
  'channel': channel,
  'serviceType': serviceType,
  'status': status,
  'items': const <dynamic>[],
  'payment': payment,
  'subtotal': 28000,
  'deliveryFee': 0,
  'createdAt': '2026-11-08T17:40:00.000Z',
};

/// JSON del snapshot del cierre (GET/POST /admin/day-close — §022).
Map<String, dynamic> dayCloseJson({bool withPostFields = false}) => {
  if (withPostFields) ...{
    'id': '7f3c9a12-4b5e-4f7a-9c1d-2e8f0a1b2c3d',
    'closedAt': '2026-11-08T04:30:12.441Z',
    'note': null,
  },
  'orderCount': 2,
  'totalAmount': 44000,
  'byMethod': const [
    {'method': 'cash', 'count': 1, 'amount': 28000},
    {'method': 'gateway', 'count': 1, 'amount': 16000},
  ],
  'cancelledCount': 1,
  'cancelledAmount': 16000,
  'orders': const <dynamic>[],
};

void main() {
  group('AdminRemoteDataSourceImpl — endpoints §041', () {
    late MockNetworkService network;
    late AdminRemoteDataSourceImpl dataSource;

    setUp(() {
      network = MockNetworkService();
      dataSource = AdminRemoteDataSourceImpl(networkService: network);
    });

    test('confirmPayment → POST /admin/orders/:id/confirm-payment '
        'SIN body y parsea la vista admin del 200 (pago cobrado + '
        'orden avanzada en el mismo hecho)', () async {
      when(
        () => network.post('/admin/orders/ord-1/confirm-payment'),
      ).thenAnswer(
        (_) async => orderJson(
          id: 'ord-1',
          status: 'done',
          payment: const {'method': 'cash', 'status': 'paid'},
        ),
      );

      final res = await dataSource.confirmPayment('ord-1');

      expect(res.id, 'ord-1');
      expect(res.status, OrderStatus.done);
      expect(res.paymentStatus, OrderPaymentStatus.paid);
      verify(() => network.post('/admin/orders/ord-1/confirm-payment'))
          .called(1);
    });

    test('fetchDayClose → GET /admin/day-close y parsea el snapshot '
        '(gateway → nequi por el modelo)', () async {
      when(
        () => network.get('/admin/day-close'),
      ).thenAnswer((_) async => dayCloseJson());

      final res = await dataSource.fetchDayClose();

      expect(res.orderCount, 2);
      expect(res.totalAmount, 44000);
      expect(res.byMethod.last.method, 'nequi');
      expect(res.cancelledCount, 1);
      verify(() => network.get('/admin/day-close')).called(1);
    });

    test('postDayClose → POST /admin/day-close SIN body (note '
        'diferida) y parsea el snapshot persistido del 201', () async {
      when(
        () => network.post('/admin/day-close'),
      ).thenAnswer((_) async => dayCloseJson(withPostFields: true));

      final res = await dataSource.postDayClose();

      expect(res.orderCount, 2);
      expect(res.totalAmount, 44000);
      expect(res.cancelledAmount, 16000);
      verify(() => network.post('/admin/day-close')).called(1);
    });
  });
}
