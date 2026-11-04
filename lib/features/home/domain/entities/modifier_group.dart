import 'package:equatable/equatable.dart';

import 'modifier_option.dart';

/// Claves estables de grupo (modifier_groups.slug del backend — el
/// comportamiento de la UI se ancla al slug, nunca al `name` editable).
abstract final class ModifierGroupSlugs {
  static const ingredients = 'ingredients';
  static const toppings = 'toppings';
  static const sauces = 'sauces';
}

/// Grupo de opciones de personalización (§019).
class ModifierGroup extends Equatable {
  const ModifierGroup({
    required this.id,
    required this.slug,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.options,
  });

  final String id;
  final String slug;
  final String name;
  final int minSelect;
  final int? maxSelect;
  final List<ModifierOption> options;

  // Igualdad por valor completa — ver ModifierOption.props.
  @override
  List<Object?> get props => [id, slug, name, minSelect, maxSelect, options];
}
