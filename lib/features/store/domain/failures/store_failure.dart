import 'package:equatable/equatable.dart';

/// Fallo consultando el estado del local — un solo caso: cualquier
/// causa (offline, 4xx/5xx, inesperado) degrada a `unknown`, nunca a
/// "cerrado" fingido. `message` solo para logging.
sealed class StoreFailure extends Equatable {
  const StoreFailure();

  @override
  List<Object?> get props => [];
}

final class StoreFetchFailure extends StoreFailure {
  const StoreFetchFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
