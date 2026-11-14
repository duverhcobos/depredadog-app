import 'package:equatable/equatable.dart';

/// Resumen del cierre de caja (espejo DayClosePreview/DayClose del
/// backend §022 — solo presentación, lo calculan los mocks):
/// cuántos pedidos entregados se archivan, el total vendido, el
/// desglose por método y los cancelados del periodo como contexto.
class AdminDayClose extends Equatable {
  const AdminDayClose({
    required this.orderCount,
    required this.totalAmount,
    required this.byMethod,
    required this.cancelledCount,
    required this.cancelledAmount,
  });

  final int orderCount;
  final int totalAmount;
  final List<AdminDayCloseMethod> byMethod;
  final int cancelledCount;
  final int cancelledAmount;

  bool get isEmpty => orderCount == 0 && cancelledCount == 0;

  @override
  List<Object?> get props => [
    orderCount,
    totalAmount,
    byMethod,
    cancelledCount,
    cancelledAmount,
  ];
}

/// Una pierna del desglose por método ("efectivo $120.000 × 5").
class AdminDayCloseMethod extends Equatable {
  const AdminDayCloseMethod({
    required this.method,
    required this.count,
    required this.amount,
  });

  /// Espejo `payment_method` del backend — cash/transfer/(gateway
  /// llega en integración).
  final String method;
  final int count;
  final int amount;

  @override
  List<Object?> get props => [method, count, amount];
}
