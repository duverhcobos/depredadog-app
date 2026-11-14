import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_action.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/l10n/app_localizations_es.dart';

AdminOrder _order(
  OrderStatus status,
  OrderPaymentStatus payment, {
  AdminServiceType serviceType = AdminServiceType.delivery,
  AdminPaymentMethod method = AdminPaymentMethod.cash,
}) => AdminOrder(
  id: 'x1',
  channel: AdminOrderChannel.online,
  serviceType: serviceType,
  status: status,
  items: const [],
  paymentMethod: method,
  paymentStatus: payment,
  total: 10000,
  placedAt: DateTime(2024, 1, 1),
);

void main() {
  group('adminOrderNextAction — matriz de 5 pasos (§036)', () {
    test('received delivery/mesa confirma primero — aunque falte '
        'cobro (contraentrega y mesa cobran al final)', () {
      for (final payment in OrderPaymentStatus.values) {
        for (final service in [
          AdminServiceType.delivery,
          AdminServiceType.dineIn,
        ]) {
          expect(
            adminOrderNextAction(
              _order(OrderStatus.received, payment, serviceType: service),
            ),
            AdminOrderAction.confirm,
          );
        }
      }
    });

    test('received recogida sin cobrar → markPaid — la puerta de la '
        'recogida (pickup nunca acepta efectivo, §036)', () {
      for (final payment in [
        OrderPaymentStatus.pending,
        OrderPaymentStatus.failed,
      ]) {
        expect(
          adminOrderNextAction(
            _order(
              OrderStatus.received,
              payment,
              serviceType: AdminServiceType.pickup,
            ),
          ),
          AdminOrderAction.markPaid,
          reason: 'recogida + $payment debe cobrarse antes de "Confirmar"',
        );
      }
      // Cobrada sí confirma.
      expect(
        adminOrderNextAction(
          _order(
            OrderStatus.received,
            OrderPaymentStatus.paid,
            serviceType: AdminServiceType.pickup,
          ),
        ),
        AdminOrderAction.confirm,
      );
    });

    test('confirmed → prepare — el cobro NO es la acción de la card '
        'en estados tempranos (en mesa se sirve antes de cobrar)', () {
      for (final payment in OrderPaymentStatus.values) {
        expect(
          adminOrderNextAction(_order(OrderStatus.confirmed, payment)),
          AdminOrderAction.prepare,
        );
      }
    });

    test('preparing → markReady — igual con o sin pago (las puertas '
        'del cobro son recogida-received y ready)', () {
      for (final payment in OrderPaymentStatus.values) {
        expect(
          adminOrderNextAction(_order(OrderStatus.preparing, payment)),
          AdminOrderAction.markReady,
        );
      }
    });

    test('ready + pago sin saldar (pending/failed) → markPaid — el '
        'cobro bloquea el Entregado (done exige PAID)', () {
      for (final payment in [
        OrderPaymentStatus.pending,
        OrderPaymentStatus.failed,
      ]) {
        expect(
          adminOrderNextAction(_order(OrderStatus.ready, payment)),
          AdminOrderAction.markPaid,
          reason: 'ready + $payment debe cobrarse antes de "Entregado"',
        );
      }
    });

    test('ready + pagado → markDone (Entregado)', () {
      expect(
        adminOrderNextAction(
          _order(OrderStatus.ready, OrderPaymentStatus.paid),
        ),
        AdminOrderAction.markDone,
      );
    });

    test('nequi sin confirmar → null en CUALQUIER estado — el '
        'webhook manda, no el dueño (§036)', () {
      // pending y failed congelan igual: ni avance ni cobro manual.
      for (final status in OrderStatus.values) {
        for (final payment in [
          OrderPaymentStatus.pending,
          OrderPaymentStatus.failed,
        ]) {
          expect(
            adminOrderNextAction(
              _order(status, payment, method: AdminPaymentMethod.nequi),
            ),
            isNull,
            reason: 'nequi $status/$payment no tiene acción — '
                'solo el webhook confirma',
          );
        }
      }
    });

    test('nequi PAGADO fluye normal — el webhook ya confirmó (§036)', () {
      expect(
        adminOrderNextAction(
          _order(
            OrderStatus.received,
            OrderPaymentStatus.paid,
            method: AdminPaymentMethod.nequi,
            serviceType: AdminServiceType.pickup,
          ),
        ),
        AdminOrderAction.confirm,
      );
      expect(
        adminOrderNextAction(
          _order(
            OrderStatus.ready,
            OrderPaymentStatus.paid,
            method: AdminPaymentMethod.nequi,
          ),
        ),
        AdminOrderAction.markDone,
      );
    });

    test('terminal → null (solo lectura, sin acción)', () {
      for (final status in [OrderStatus.done, OrderStatus.cancelled]) {
        for (final payment in OrderPaymentStatus.values) {
          expect(adminOrderNextAction(_order(status, payment)), isNull);
        }
      }
    });
  });

  group('adminOrderActionLabel — labels por canal (§036)', () {
    final l10n = AppLocalizationsEs();

    test('markReady cambia por serviceType: delivery "Va en camino", '
        'dineIn "Servir", pickup "Listo p/recoger"', () {
      expect(
        adminOrderActionLabel(
          l10n,
          AdminOrderAction.markReady,
          serviceType: AdminServiceType.delivery,
        ),
        'Va en camino',
      );
      expect(
        adminOrderActionLabel(
          l10n,
          AdminOrderAction.markReady,
          serviceType: AdminServiceType.dineIn,
        ),
        'Servir',
      );
      expect(
        adminOrderActionLabel(
          l10n,
          AdminOrderAction.markReady,
          serviceType: AdminServiceType.pickup,
        ),
        'Listo p/recoger',
      );
      // Sin serviceType → fallback pickup.
      expect(
        adminOrderActionLabel(l10n, AdminOrderAction.markReady),
        'Listo p/recoger',
      );
    });

    test('el resto de la matriz tiene su label', () {
      expect(
        adminOrderActionLabel(l10n, AdminOrderAction.confirm),
        'Confirmar',
      );
      expect(adminOrderActionLabel(l10n, AdminOrderAction.prepare), 'Preparar');
      expect(adminOrderActionLabel(l10n, AdminOrderAction.markPaid), 'Registrar pago');
      expect(
        adminOrderActionLabel(l10n, AdminOrderAction.markDone),
        'Entregado',
      );
    });
  });
}
