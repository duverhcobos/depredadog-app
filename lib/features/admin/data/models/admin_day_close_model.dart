import '../../domain/entities/admin_day_close.dart';

/// JSON del cierre de caja (GET/POST /admin/day-close — backend
/// §022): orderCount/totalAmount/byMethod[]/cancelled*. El POST
/// además devuelve id/closedAt/note que la UI no consume (el
/// resumen es el snapshot de éxito).
/// `byMethod[].method` llega crudo del pago: 'gateway' se
/// normaliza a 'nequi' — la misma regla de AdminOrderModel (§038)
/// para que la pantalla lo pinte "Nequi", no "gateway".
class AdminDayCloseModel extends AdminDayClose {
  AdminDayCloseModel.fromJson(Map<String, dynamic> json)
    : super(
        orderCount: json['orderCount'] as int? ?? 0,
        totalAmount: json['totalAmount'] as int? ?? 0,
        byMethod: [
          for (final m in (json['byMethod'] as List? ?? const []))
            AdminDayCloseMethod(
              method: m['method'] == 'gateway'
                  ? 'nequi'
                  : (m['method'] as String? ?? 'unknown'),
              count: m['count'] as int? ?? 0,
              amount: m['amount'] as int? ?? 0,
            ),
        ],
        cancelledCount: json['cancelledCount'] as int? ?? 0,
        cancelledAmount: json['cancelledAmount'] as int? ?? 0,
      );
}
