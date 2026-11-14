import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_card.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_chips.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

AdminOrder _order(AdminOrderChannel channel) => AdminOrder(
  id: 'x1',
  channel: channel,
  serviceType: AdminServiceType.pickup,
  status: OrderStatus.received,
  items: const [],
  paymentMethod: AdminPaymentMethod.cash,
  paymentStatus: OrderPaymentStatus.paid,
  subtotal: 10000,
  deliveryFee: 0,
  // Reciente: una fecha vieja dibuja un "hace N" larguísimo en la
  // fila cliente y revienta la card en superficies angostas.
  placedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  customerName: 'Cliente Prueba',
);

/// Card aislada en Scaffold — el InkWell de navegación no se toca
/// (no hay GoRouter en el harness).
Future<void> _pumpCard(WidgetTester tester, AdminOrder order) {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: AdminOrderCard(order: order, busy: false)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
    ),
  );
}

void main() {
  group('AdminOrderCard — etiqueta de canal en la esquina (§036)', () {
    testWidgets('online → susurro "Online" arriba a la derecha',
        (tester) async {
      await _pumpCard(tester, _order(AdminOrderChannel.online));

      expect(find.byType(AdminChannelTag), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget);

      // La etiqueta vive a la DERECHA del chip de servicio.
      final tagRight = tester.getTopRight(find.byType(AdminChannelTag)).dx;
      final chipRight = tester.getTopRight(find.byType(AdminServiceChip)).dx;
      expect(tagRight, greaterThan(chipRight));
    });

    testWidgets('presencial → susurro "Presencial" con ícono tienda',
        (tester) async {
      await _pumpCard(tester, _order(AdminOrderChannel.presencial));

      expect(find.text('Presencial'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });

    testWidgets('con showStatusChip el canal antecede al chip de '
        'estado (historial)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: AdminOrderCard(
              order: _order(AdminOrderChannel.presencial),
              busy: false,
              showStatusChip: true,
            ),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
        ),
      );

      final tagRight =
          tester.getTopRight(find.byType(AdminChannelTag)).dx;
      final statusLeft =
          tester.getTopLeft(find.byType(AdminOrderStatusChip)).dx;
      expect(tagRight, lessThan(statusLeft));
    });
  });
}
