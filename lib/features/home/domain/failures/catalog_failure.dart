import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo del catálogo — el
/// repository impl es el único que traduce NetworkException; la UI solo
/// hace pattern-matching para elegir el mensaje (misma convención que
/// AuthFailure).
sealed class CatalogFailure extends Equatable {
  const CatalogFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad (INetworkInfo o timeout de conexión).
class CatalogOfflineFailure extends CatalogFailure {
  const CatalogOfflineFailure();
}

/// Cualquier otro error (5xx, timeout, parseo, inesperado) — conserva el
/// mensaje solo para logging; la UI muestra texto genérico propio.
class CatalogServerFailure extends CatalogFailure {
  const CatalogServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
