import '../../../../l10n/app_localizations.dart';
import '../../../orders/presentation/utils/format_order_date.dart';

/// "hace 12 min" / "hace 3 h" / fecha corta — tiempo transcurrido del
/// pedido en la cola admin (§034). La cola se opera por frescura:
/// bajo la hora manda el minuto, bajo el día la hora; más viejo ya se
/// lee como fecha (misma util de pedidos — formato único autorizado).
String formatElapsed(DateTime placedAt, AppLocalizations l10n) {
  final elapsed = DateTime.now().difference(placedAt);
  if (elapsed.inMinutes < 60) {
    // Nunca "hace 0 min" — un pedido recién caído se lee "hace 1 min".
    final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
    return l10n.adminOrderElapsedMinutes(minutes);
  }
  if (elapsed.inHours < 24) return l10n.adminOrderElapsedHours(elapsed.inHours);
  return formatOrderDate(placedAt);
}
