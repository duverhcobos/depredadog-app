import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Resultado de la carga de Cocina — cada pierna degrada por separado
/// (la cola puede llegar aunque el historial falle, y viceversa; misma
/// convención de OrdersDataResult §027).
class AdminQueueData {
  const AdminQueueData({required this.active, required this.history});

  final Either<AdminFailure, List<AdminOrder>> active;
  final Either<AdminFailure, AdminHistoryPage> history;
}

/// SOLID (SRP): carga inicial / pull-to-refresh / reload al entrar al tab —
/// bucket active + página 1 del historial en paralelo.
class LoadAdminQueueUseCase {
  const LoadAdminQueueUseCase(this._repo);

  final IAdminRepository _repo;

  Future<AdminQueueData> call() async {
    final results = await Future.wait([
      _repo.getActiveOrders(),
      _repo.getHistoryOrders(1),
    ]);
    return AdminQueueData(
      active: results[0] as Either<AdminFailure, List<AdminOrder>>,
      history: results[1] as Either<AdminFailure, AdminHistoryPage>,
    );
  }
}
