import 'package:equatable/equatable.dart';

/// Acción del modificador — espejo del enum del backend
/// (order_item_modifiers.action, propuesta 013): un ítem del
/// carrito se serializa 1:1 a filas added/removed sin traducir.
enum CartModifierAction { added, removed }

/// Grupo de personalización de donde vino la fila (§021b) — snapshot
/// para que el desplegable del tile pueda seccionar el detalle
/// (Ingredientes / Adicionales / Toppings / Salsas) sin resolver el
/// producto en la carta (puede ya no existir). Los `removed` y las
/// filas `added` de un reemplazo siempre son `ingredient`.
enum CartModifierGroup { ingredient, extra, topping, sauce }

/// Una fila de personalización del ítem (§020). `optionId` es el id
/// real de modifier_options del backend; `optionName` y `priceDelta`
/// son SNAPSHOTS del momento de agregar — el nombre no cambia si la
/// carta se actualiza, y la revalidación de precios es server-side
/// al crear la orden (pendiente backend/009).
class CartModifier extends Equatable {
  const CartModifier({
    required this.optionId,
    required this.optionName,
    required this.action,
    required this.priceDelta,
    this.times = 1,
    this.replacesOptionId,
    this.group,
  });

  final String optionId;
  final String optionName;
  final CartModifierAction action;

  /// Extra cobrado: precio real en adicionales; 0 en quitados,
  /// toppings, salsas y reemplazos gratis.
  final int priceDelta;

  /// Solo en filas `added` de un reemplazo gratis: id del ingrediente
  /// agotado que esta opción reemplaza (§021). Sin él, el modo edición
  /// no puede distinguir "Tostacos gratis por mozzarella agotada" de
  /// "Tostacos gratis porque sí" — la fila added apunta al removed.
  /// No participa en sameConfiguration (a nivel plato es la misma
  /// personalización).
  final String? replacesOptionId;

  /// Grupo de origen de la opción (§021b) — el panel secciona con él.
  /// Null en filas viejas/fixtures: una `added` sin etiqueta cae a
  /// Adicionales (fallback razonable). Tampoco entra a
  /// sameConfiguration — una opción nunca vive en dos grupos.
  final CartModifierGroup? group;

  /// Porciones del adicional (§045) — solo aplica a `added` de extras
  /// cobrados; `priceDelta` ya es el total de línea (extra × times).
  /// Removed, toppings, salsas y reemplazos siempre son 1.
  final int times;

  @override
  List<Object?> get props => [
    optionId,
    optionName,
    action,
    priceDelta,
    times,
    replacesOptionId,
    group,
  ];
}
