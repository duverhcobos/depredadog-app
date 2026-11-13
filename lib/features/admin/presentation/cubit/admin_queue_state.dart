import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';

/// Bucket visible de la cola admin (segmento del filtro — espejo del
/// query `bucket` de GET /admin/orders): active = cola viva
/// (pending/confirmed/preparing), history = terminados/cancelados.
enum AdminQueueFilter { active, history }

/// Estado del tab Cocina (§034, solo presentación — mocks del cubit):
/// las dos bandejas + el filtro activo + flags de carga/error. A
/// diferencia de OrdersState no hay paginación ni degradación por
/// pierna todavía — el mock es un solo load; la integración decide
/// si history pagina como el del cliente.
class AdminQueueState extends Equatable {
  const AdminQueueState({
    this.active = const [],
    this.history = const [],
    this.filter = AdminQueueFilter.active,
    this.dataLoading = true,
    this.failed = false,
  });

  /// Cola viva — pedidos por atender (el orden de escaneo lo arma
  /// `visible`: por-confirmar primero, luego FIFO de cocina).
  final List<AdminOrder> active;

  /// Terminados y cancelados, más reciente primero.
  final List<AdminOrder> history;

  /// Segmento marcado del filtro Activos|Historial.
  final AdminQueueFilter filter;

  /// Carga inicial / refresh completo en vuelo — arranca en true
  /// (los datos mock llegan con el primer load).
  final bool dataLoading;

  /// El load falló — estado de error con reintento (inalcanzable en
  /// la fase mock; la forma ya queda para la integración).
  final bool failed;

  /// Lista del segmento visible según el filtro. Activa: los
  /// POR-CONFIRMAR primero (el semáforo prioriza la acción del dueño —
  /// misma regla del chip "Pendiente" sólido §034b) y dentro de cada
  /// grupo FIFO de cocina (el que más esperó va arriba). Historial:
  /// más reciente primero, como log.
  List<AdminOrder> get visible {
    if (filter == AdminQueueFilter.history) {
      return [...history]..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    }
    final pending = <AdminOrder>[];
    final rest = <AdminOrder>[];
    for (final o in active) {
      (o.status == OrderStatus.received ? pending : rest).add(o);
    }
    int byAge(AdminOrder a, AdminOrder b) => a.placedAt.compareTo(b.placedAt);
    return [...pending..sort(byAge), ...rest..sort(byAge)];
  }

  bool get isEmpty => active.isEmpty && history.isEmpty;

  AdminQueueState copyWith({
    List<AdminOrder>? active,
    List<AdminOrder>? history,
    AdminQueueFilter? filter,
    bool? dataLoading,
    bool? failed,
  }) => AdminQueueState(
    active: active ?? this.active,
    history: history ?? this.history,
    filter: filter ?? this.filter,
    dataLoading: dataLoading ?? this.dataLoading,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [active, history, filter, dataLoading, failed];
}
