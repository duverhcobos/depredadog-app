import 'package:equatable/equatable.dart';

/// Opción seleccionable de un grupo de modificadores (§019):
/// ingrediente, topping o salsa del contrato GET /catalog.
/// `includedByDefault` es POR PRODUCTO (product_modifier_options).
class ModifierOption extends Equatable {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.extraPrice,
    required this.isAvailable,
    required this.isRemovable,
    required this.includedByDefault,
    this.isReplaceable = true,
    this.isReplacementEligible = true,
    this.isEssential = false,
  });

  final String id;
  final String name;

  /// Cargo al agregarla como adicional (0 cuando es gratis).
  final int extraPrice;

  /// false = agotada hoy — la UI la muestra deshabilitada.
  final bool isAvailable;

  /// false = fija del producto (pan/salchicha) — no se puede quitar.
  final bool isRemovable;

  /// true = viene en el producto salvo que el cliente la quite.
  final bool includedByDefault;

  /// Regla del cambio gratis (§019): si la opción incluida se agota,
  /// ¿admite ser cambiada por un adicional? false en el corazón del
  /// producto (salchicha) — el dueño marca el producto agotado.
  final bool isReplaceable;

  /// ¿La opción puede ofrecerse como reemplazo gratis? false en lo que
  /// no se regala (salchicha — doble cobrado); toppings/salsas sí.
  final bool isReplacementEligible;

  /// Ingrediente ESENCIAL: si se agota estando incluido, el producto
  /// entero queda agotado (salchicha/pan — sin ellos no hay perro).
  /// Como extra agotado solo se deshabilita; ver `isSellable` del
  /// producto.
  final bool isEssential;

  // Igualdad por VALOR completa — el refresh de /catalog trae el mismo
  // id con flags distintos (isAvailable): con props=[id] el estado no
  // cambiaría y el Cubit descartaría el emit (bug visto en vivo).
  @override
  List<Object?> get props => [
    id,
    name,
    extraPrice,
    isAvailable,
    isRemovable,
    includedByDefault,
    isReplaceable,
    isReplacementEligible,
    isEssential,
  ];
}
