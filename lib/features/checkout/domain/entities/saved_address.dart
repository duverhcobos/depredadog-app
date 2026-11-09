import 'package:equatable/equatable.dart';

/// Clase de dirección guardada — decide el ícono de la fila en el
/// checkout (casa/trabajo/otra). Puramente visual: el backend solo
/// guarda textos (§022, mock).
enum SavedAddressType { home, work, other }

/// Ubicación guardada del cliente — viene de `GET /addresses`
/// (backend 014, §025 la conectó) y se crea con `POST /addresses`
/// desde "Guardar esta ubicación" del checkout.
///
/// La zona del negocio no tiene nomenclatura de calles — la entrega se
/// guía por PUNTOS DE REFERENCIA ("casa blanca frente a la cancha"),
/// con sector opcional y pin de Google Maps como apoyo (decisión del
/// usuario §022a).
class SavedAddress extends Equatable {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.landmark,
    this.neighborhood = '',
    this.type = SavedAddressType.other,
  });

  final String id;

  /// Nombre corto que el cliente le puso ("Casa", "Trabajo").
  final String label;

  /// Punto de referencia ("Casa blanca frente a la cancha") — el
  /// equivalente a la "dirección" en zonas sin nomenclatura (§022a).
  final String landmark;

  /// Barrio, vereda o sector — opcional en zonas sin división formal.
  final String neighborhood;

  final SavedAddressType type;

  /// Línea de detalle bajo el label en la fila del checkout — sector
  /// solo cuando existe (es opcional, §022a).
  String get detail =>
      neighborhood.isEmpty ? landmark : '$landmark · $neighborhood';

  @override
  List<Object?> get props => [id, label, landmark, neighborhood, type];
}
