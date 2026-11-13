import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import 'admin_queue_state.dart';

/// SOLID (SRP): único dueño del estado del tab Cocina (§034 — solo
/// presentación, patrón §026/§030: contrato real, datos ficticios).
/// SINGLETON como OrdersCubit: lo resuelven el pageBuilder de /admin
/// (load por visita) y la pantalla por BlocProvider.value. En
/// integración `load()` = GET /admin/orders?bucket=active|history —
/// la forma del estado ya es la del listado real.
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({List<AdminOrder>? mockActive, List<AdminOrder>? mockHistory})
    : _mockActive = mockActive ?? _defaultActive(),
      _mockHistory = mockHistory ?? _defaultHistory(),
      super(const AdminQueueState());

  final List<AdminOrder> _mockActive;
  final List<AdminOrder> _mockHistory;

  /// Guardia de reentry — load corre por visita al tab, por pull-
  /// to-refresh y por reintento; un loading paralelo no compite.
  bool _loading = false;

  /// Carga inicial / pull-to-refresh / reload al entrar al tab —
  /// 400ms de latencia simulada (misma convención del mock §023).
  /// dataLoading solo existe sin datos previos: en refresh el
  /// contenido queda pintado (el pull no desmonta el árbol).
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      emit(state.copyWith(dataLoading: state.isEmpty, failed: false));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (isClosed) return;
      emit(
        state.copyWith(
          active: _mockActive,
          history: _mockHistory,
          dataLoading: false,
        ),
      );
    } finally {
      _loading = false;
    }
  }

  /// Marca el segmento Activos|Historial — local, sin fetch (el mock
  /// ya trajo las dos bandejas en el mismo load).
  void setFilter(AdminQueueFilter filter) =>
      emit(state.copyWith(filter: filter));

  /// Cola viva mock: cubre las combinaciones que la card debe
  /// mostrar — canal online/presencial, cliente con nombre vs.
  /// "En el local · Mesa N", estados pendiente/confirmado/plancha y
  /// pago efectivo/transferencia en distintos estados.
  static List<AdminOrder> _defaultActive() {
    final now = DateTime.now();
    return [
      // Online · pending · transferencia pendiente de pago — el
      // caso "me escriben por WhatsApp que ya pagaron" del dueño.
      AdminOrder(
        id: 'adm-1',
        channel: AdminOrderChannel.online,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 2,
            unitPrice: 25000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 6000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        total: 56000,
        placedAt: now.subtract(const Duration(minutes: 12)),
        customerName: 'Ana Uno',
      ),
      // Presencial dine_in con mesa — "En el local · Mesa N".
      AdminOrder(
        id: 'adm-2',
        channel: AdminOrderChannel.presencial,
        status: OrderStatus.confirmed,
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        total: 14000,
        placedAt: now.subtract(const Duration(minutes: 4)),
        tableLabel: 'Mesa 3',
      ),
      // Online pickup ya pago y en la plancha.
      AdminOrder(
        id: 'adm-3',
        channel: AdminOrderChannel.online,
        status: OrderStatus.preparing,
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
          ),
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        total: 34000,
        placedAt: now.subtract(const Duration(minutes: 26)),
        customerName: 'Beto Dos',
      ),
      // Presencial de mostrador sin mesa ni nombre — "En el local".
      AdminOrder(
        id: 'adm-4',
        channel: AdminOrderChannel.presencial,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 2,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        total: 36000,
        placedAt: now.subtract(const Duration(minutes: 1)),
      ),
      // Presencial con mesa — LA ORDEN GRANDE: 1× de cada producto
      // del menú (7 líneas) — cubre el resumen largo de la card
      // (maxLines 2 → la cola real trunca con "…").
      AdminOrder(
        id: 'adm-7',
        channel: AdminOrderChannel.presencial,
        status: OrderStatus.confirmed,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
          ),
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 1,
            unitPrice: 18000,
          ),
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
          ),
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de Papas',
            quantity: 1,
            unitPrice: 10000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        total: 118000,
        placedAt: now.subtract(const Duration(minutes: 8)),
        tableLabel: 'Mesa 5',
      ),
    ];
  }

  /// Historial mock: un terminado online y un cancelado presencial.
  static List<AdminOrder> _defaultHistory() {
    final now = DateTime.now();
    return [
      AdminOrder(
        id: 'adm-5',
        channel: AdminOrderChannel.online,
        status: OrderStatus.done,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        total: 25000,
        placedAt: now.subtract(const Duration(hours: 3)),
        customerName: 'Carla Tres',
      ),
      AdminOrder(
        id: 'adm-6',
        channel: AdminOrderChannel.presencial,
        status: OrderStatus.cancelled,
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 2,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        // Se canceló antes de cobrar — el dato queda pending pero la
        // card lo suprime en estado cancelado (revisor-ui §034: un
        // "Pago pendiente" en un cancelado grita una deuda fantasma).
        paymentStatus: OrderPaymentStatus.pending,
        total: 28000,
        placedAt: now.subtract(const Duration(hours: 5)),
        tableLabel: 'Mesa 2',
      ),
    ];
  }
}
