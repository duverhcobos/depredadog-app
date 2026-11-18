import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/data/models/admin_day_close_model.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';

/// JSON del snapshot del cierre (GET/POST /admin/day-close — backend
/// §022): orderCount/totalAmount/byMethod[]/cancelled*. El POST suma
/// id/closedAt/note que el modelo ignora (la UI no los consume).
Map<String, dynamic> dayCloseJson({
  int orderCount = 2,
  int totalAmount = 44000,
  List<dynamic>? byMethod,
  int cancelledCount = 1,
  int cancelledAmount = 16000,
  bool withPostFields = false,
}) => {
  if (withPostFields) ...{
    'id': '7f3c9a12-4b5e-4f7a-9c1d-2e8f0a1b2c3d',
    'closedAt': '2026-11-08T04:30:12.441Z',
    'note': 'Cierre de lunes',
  },
  'orderCount': orderCount,
  'totalAmount': totalAmount,
  'byMethod': byMethod ??
      [
        {'method': 'cash', 'count': 1, 'amount': 28000},
        {'method': 'transfer', 'count': 1, 'amount': 16000},
      ],
  'cancelledCount': cancelledCount,
  'cancelledAmount': cancelledAmount,
  // El detalle de pedidos archivados existe en el payload pero la
  // pantalla no lo lista hoy (fuera de alcance §041).
  'orders': const <dynamic>[],
};

void main() {
  group('AdminDayCloseModel (§041)', () {
    test('parse completo del snapshot — contadores, total, desglose '
        'por método y cancelados como contexto', () {
      final model = AdminDayCloseModel.fromJson(dayCloseJson());

      expect(model.orderCount, 2);
      expect(model.totalAmount, 44000);
      expect(
        model.byMethod,
        equals([
          const AdminDayCloseMethod(method: 'cash', count: 1, amount: 28000),
          const AdminDayCloseMethod(
            method: 'transfer',
            count: 1,
            amount: 16000,
          ),
        ]),
      );
      expect(model.cancelledCount, 1);
      expect(model.cancelledAmount, 16000);
    });

    test("byMethod[].method 'gateway' → 'nequi' — la misma regla de "
        'AdminOrderModel (§038): la pantalla lo pinta "Nequi", no '
        '"gateway"', () {
      final model = AdminDayCloseModel.fromJson(
        dayCloseJson(
          byMethod: [
            {'method': 'gateway', 'count': 2, 'amount': 50000},
            {'method': 'cash', 'count': 1, 'amount': 14000},
          ],
        ),
      );

      expect(model.byMethod.first.method, 'nequi');
      expect(model.byMethod.last.method, 'cash');
    });

    test('faltantes → ceros: el cierre vacío del backend (sin nada '
        'pendiente de cierre) llega con campos en cero o ausentes', () {
      final model = AdminDayCloseModel.fromJson(const {});

      expect(model.orderCount, 0);
      expect(model.totalAmount, 0);
      expect(model.byMethod, isEmpty);
      expect(model.cancelledCount, 0);
      expect(model.cancelledAmount, 0);
      expect(model.isEmpty, isTrue);
    });

    test('el POST devuelve id/closedAt/note extra — el modelo los '
        'ignora sin romper (el resumen es el snapshot de éxito)', () {
      final model = AdminDayCloseModel.fromJson(
        dayCloseJson(withPostFields: true),
      );

      expect(model.orderCount, 2);
      expect(model.totalAmount, 44000);
      expect(model.byMethod, hasLength(2));
    });

    test('método desconocido o nulo → "unknown" defensivo (el '
        'desglose nunca truena por un método nuevo del backend)', () {
      final model = AdminDayCloseModel.fromJson(
        dayCloseJson(
          byMethod: [
            {'method': 'tarjeta', 'count': 1, 'amount': 9000},
            {'count': 1, 'amount': 5000},
          ],
        ),
      );

      expect(model.byMethod.first.method, 'tarjeta');
      expect(model.byMethod.last.method, 'unknown');
    });
  });
}
