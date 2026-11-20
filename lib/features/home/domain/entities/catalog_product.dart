import 'package:equatable/equatable.dart';

import 'modifier_group.dart';
import 'modifier_option.dart';

/// Mínimo de porciones al agregar un adicional (§045) — no hay tope
/// superior (decisión del usuario); el stepper solo clampa por abajo.
const int kMinExtraTimes = 1;

/// Producto del menú (§019). Helpers de personalización replican las
/// reglas del modelo aprobado §018 — ver la propuesta.
class CatalogProduct extends Equatable {
  const CatalogProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.basePrice,
    required this.imageUrl,
    required this.isAvailable,
    required this.isFeatured,
    required this.isCombo,
    required this.modifierGroups,
  });

  final String id;

  /// Clave estable: mapeo de assets locales + segmento de ruta.
  final String slug;
  final String name;

  /// `description` del backend (tagline de la carta).
  final String tagline;
  final int basePrice;

  /// null mientras no haya fotos reales (pendientes backend/006) — la
  /// presentación cae al asset local por slug.
  final String? imageUrl;

  final bool isAvailable;
  final bool isFeatured;
  final bool isCombo;
  final List<ModifierGroup> modifierGroups;

  /// Grupo por slug; null si el producto no lo tiene enlazado.
  ModifierGroup? groupBySlug(String slug) {
    for (final g in modifierGroups) {
      if (g.slug == slug) return g;
    }
    return null;
  }

  /// Agotado efectivo (regla de insumo esencial §019): el producto se
  /// apaga si el dueño lo marcó O si un ingrediente INCLUIDO esencial
  /// se agotó — sin salchicha/pan no hay perro. Las pantallas consumen
  /// esto para "Agotado"/tap, no el flag crudo `isAvailable`.
  bool get isSellable =>
      isAvailable &&
      !modifierGroups.any(
        (g) => g.options.any(
          (o) => o.includedByDefault && o.isEssential && !o.isAvailable,
        ),
      );

  /// "¿Se le quita algo?": incluidos por defecto Y removibles (pan y
  /// salchicha quedan fuera — fijos).
  List<ModifierOption> get removableIngredients =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where((o) => o.includedByDefault && o.isRemovable)
          .toList();

  /// "¿Le agregamos algo más?": las que NO vienen por defecto, más TODA
  /// incluida con precio — cualquier ingrediente del perro se repite
  /// pagándolo como adicional (§045). Pan y salchicha quedan fuera
  /// porque su extra_price es 0 — no se venden sueltos.
  List<ModifierOption> get additionalOptions =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where((o) => !o.includedByDefault || o.extraPrice > 0)
          .toList();

  List<ModifierOption> get toppingOptions =>
      groupBySlug(ModifierGroupSlugs.toppings)?.options ??
      const <ModifierOption>[];

  List<ModifierOption> get sauceOptions =>
      groupBySlug(ModifierGroupSlugs.sauces)?.options ??
      const <ModifierOption>[];

  /// Texto de composición: nombres de los ingredientes incluidos por
  /// defecto unidos "A, B y C." — reemplaza `ingredients` del mock.
  String get ingredientsSummary {
    final names =
        (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
                const <ModifierOption>[])
            .where((o) => o.includedByDefault)
            .map((o) => o.name)
            .toList();
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names.first}.';
    return '${names.sublist(0, names.length - 1).join(', ')} '
        'y ${names.last}.';
  }

  // Igualdad por VALOR completa — el refresh trae el mismo id con
  // flags distintos (isAvailable/isFeatured): con props=[id] el emit
  // se descartaba y la UI quedaba vieja (bug visto en vivo §019).
  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    tagline,
    basePrice,
    imageUrl,
    isAvailable,
    isFeatured,
    isCombo,
    modifierGroups,
  ];
}
