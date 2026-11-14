import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_day_close.dart';
import '../../domain/entities/admin_order.dart';

/// Estado del tab Cocina kanban (§036, solo presentación — mocks):
/// una sola bandeja `active` (en curso + entregados sin cerrar) de
/// la que se derivan los 5 carriles; `history` guarda los archivados
/// por cierre + cancelados; `dayClose` es el preview del cierre que
/// ve la pantalla /admin/day-close.
class AdminQueueState extends Equatable {
  const AdminQueueState({
    this.active = const [],
    this.history = const [],
    this.dataLoading = true,
    this.failed = false,
    this.busyOrderIds = const {},
    this.dayClose,
    this.dayCloseBusy = false,
  });

  /// Cola viva: en curso (received→ready) + done SIN cerrar — el
  /// entregado espera al cierre de caja para archivarse.
  final List<AdminOrder> active;

  /// Archivados (done cerrados + cancelados), más reciente primero.
  final List<AdminOrder> history;

  /// Carga inicial / refresh completo en vuelo — arranca en true
  /// (los datos mock llegan con el primer load).
  final bool dataLoading;

  /// El load falló — estado de error con reintento (inalcanzable en
  /// la fase mock; la forma ya queda para la integración).
  final bool failed;

  /// Pedidos con una operación mock en vuelo (§035 — advance /
  /// markPaid / cancel): prende el spinner inline del botón de
  /// acción en card y detalle, y bloquea el doble-tap — la misma
  /// guardia que el UPDATE condicional del backend resuelve con 409.
  final Set<String> busyOrderIds;

  /// Preview del cierre calculado en mocks — null hasta que la
  /// pantalla /admin/day-close lo pida.
  final AdminDayClose? dayClose;

  /// El cierre mock está en vuelo — el CTA de confirmar muestra
  /// spinner (convención checkout).
  final bool dayCloseBusy;

  /// Carriles del kanban en orden fijo — done va último (es el
  /// "carril entregados" que espera el cierre).
  static const laneStatuses = [
    OrderStatus.received,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.done,
  ];

  /// Pedidos del carril en FIFO de cocina (más viejo arriba — el
  /// que más espera se atiende primero).
  List<AdminOrder> laneOrders(OrderStatus status) => [
    for (final o in active)
      if (o.status == status) o,
  ]..sort((a, b) => a.placedAt.compareTo(b.placedAt));

  /// Entregados esperando cierre — alimenta el contador del botón.
  int get deliveredCount =>
      active.where((o) => o.status == OrderStatus.done).length;

  bool get isEmpty => active.isEmpty && history.isEmpty;

  /// La orden VIVA por id, buscada en ambos buckets — el detalle la
  /// resuelve así (§035): tras cada acción refleja el estado nuevo
  /// sin re-navegar, y un terminal sigue encontrándose en history.
  AdminOrder? orderById(String id) {
    for (final list in [active, history]) {
      for (final order in list) {
        if (order.id == id) return order;
      }
    }
    return null;
  }

  AdminQueueState copyWith({
    List<AdminOrder>? active,
    List<AdminOrder>? history,
    bool? dataLoading,
    bool? failed,
    Set<String>? busyOrderIds,
    AdminDayClose? Function()? dayClose,
    bool? dayCloseBusy,
  }) => AdminQueueState(
    active: active ?? this.active,
    history: history ?? this.history,
    dataLoading: dataLoading ?? this.dataLoading,
    failed: failed ?? this.failed,
    busyOrderIds: busyOrderIds ?? this.busyOrderIds,
    dayClose: dayClose != null ? dayClose() : this.dayClose,
    dayCloseBusy: dayCloseBusy ?? this.dayCloseBusy,
  );

  @override
  List<Object?> get props => [
    active,
    history,
    dataLoading,
    failed,
    busyOrderIds,
    dayClose,
    dayCloseBusy,
  ];
}
