/// Catálogo PROVISIONAL de la fase presentación (§017): la carta real
/// definida por el usuario (menú Depredadog — precios COP
/// provisionales). En integración viene de GET /catalog/* y este
/// archivo se elimina. Los textos de producto son DATA del negocio,
/// no chrome de UI — quedan en español como en la carta.
enum CatalogCategory { dogs, more, drinks, combos }

/// Metadatos de presentación por categoría: segmento de ruta e imagen
/// representativa (PNG sin fondo).
extension CatalogCategoryX on CatalogCategory {
  /// Segmento de ruta hija: /home/category/{segment}.
  String get segment => switch (this) {
    CatalogCategory.dogs => 'perros',
    CatalogCategory.more => 'mas',
    CatalogCategory.drinks => 'bebidas',
    CatalogCategory.combos => 'combos',
  };

  /// Imagen representativa en la card de categoría del home.
  String get coverAsset => switch (this) {
    CatalogCategory.dogs => 'assets/images/products/perro_depredador.png',
    CatalogCategory.more => 'assets/images/products/manada_papas.png',
    CatalogCategory.drinks => 'assets/images/products/cat_bebidas.png',
    CatalogCategory.combos => 'assets/images/products/cat_combos.png',
  };

  static CatalogCategory fromSegment(String segment) => switch (segment) {
    'mas' => CatalogCategory.more,
    'bebidas' => CatalogCategory.drinks,
    'combos' => CatalogCategory.combos,
    _ => CatalogCategory.dogs,
  };
}

/// Ingrediente del catálogo GLOBAL (§018): cada perro referencia los
/// que trae por defecto; el resto se ofrece como adicional con su
/// `additionalPrice`. Pan nunca aparece en el detalle (fijo) y la
/// salchicha solo como adicional (doble salchicha clásica).
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.additionalPrice,
  });

  final String id;
  final String name;
  final int additionalPrice;
}

const ingredientCatalog = <Ingredient>[
  Ingredient(
    id: 'salchicha',
    name: 'Salchicha americana',
    additionalPrice: 5000,
  ),
  Ingredient(id: 'carne', name: 'Carne desmechada', additionalPrice: 5000),
  Ingredient(id: 'pollo', name: 'Pollo desmechado', additionalPrice: 4500),
  Ingredient(id: 'chile', name: 'Chile con carne', additionalPrice: 4500),
  Ingredient(id: 'tocineta', name: 'Tocineta crocante', additionalPrice: 4000),
  Ingredient(id: 'salami', name: 'Salami', additionalPrice: 4000),
  Ingredient(id: 'mozzarella', name: 'Queso mozzarella', additionalPrice: 3500),
  Ingredient(
    id: 'cheddar',
    name: 'Salsa de queso cheddar',
    additionalPrice: 3000,
  ),
  Ingredient(id: 'pina', name: 'Piña en trozos', additionalPrice: 3000),
  Ingredient(id: 'maiz', name: 'Maíz dulce', additionalPrice: 2500),
  Ingredient(id: 'huevo', name: 'Huevo de codorniz', additionalPrice: 2500),
];

/// Toppings y salsas: catálogos globales GRATIS e ilimitados (§018).
const toppingCatalog = <String>[
  'Papa ripio',
  'Queso rallado',
  'Cebolla crispy',
  'Tocineta picada',
  'Jalapeños',
];

const sauceCatalog = <String>[
  'Ketchup',
  'Mayonesa',
  'Mostaza',
  'Salsa de piña',
  'Salsa rosada',
  'Salsa tártara',
  'BBQ',
];

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.ingredients,
    required this.priceCop,
    required this.imageAsset,
    required this.category,
    required this.ingredientIds,
  });

  final String id;
  final String name;
  final String tagline;
  final String ingredients;
  final int priceCop;
  final String imageAsset;
  final CatalogCategory category;

  /// Ingredientes que trae por defecto (ids de ingredientCatalog,
  /// sin pan ni salchicha — fijos). Son los ÚNICOS quitables.
  final List<String> ingredientIds;
}

/// Ingredientes por defecto de un producto (objetos resueltos).
List<Ingredient> ingredientesOf(CatalogItem item) =>
    ingredientCatalog.where((i) => item.ingredientIds.contains(i.id)).toList();

/// Adicionales disponibles para un producto: ingredientes del catálogo
/// que NO trae por defecto (§018 — "ingrediente de otro perro").
List<Ingredient> adicionalesFor(CatalogItem item) =>
    ingredientCatalog.where((i) => !item.ingredientIds.contains(i.id)).toList();

/// 14000 → "$14.000" (formato COP con separador de miles por punto).
String formatCop(int price) {
  final s = price.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}

/// Carta del menú — perros + & Más. Bebidas y Combos aún sin productos.
const depredadorItem = CatalogItem(
  id: 'depredador',
  name: 'El Depredador',
  tagline: 'El alfa come de todo.',
  ingredients:
      'Salchicha americana, carne desmechada, chile con carne, tocineta '
      'crocante, piña en trozos, maíz dulce, mozzarella y huevo de codorniz.',
  priceCop: 25000,
  imageAsset: 'assets/images/products/perro_depredador.png',
  category: CatalogCategory.dogs,
  ingredientIds: [
    'carne',
    'chile',
    'tocineta',
    'pina',
    'maiz',
    'mozzarella',
    'huevo',
  ],
);

const catalogMockItems = <CatalogItem>[
  CatalogItem(
    id: 'cachorro',
    name: 'El Cachorro',
    tagline: 'El primer mordisco de la manada.',
    ingredients:
        'Salchicha americana, queso mozzarella fundido y huevo de codorniz.',
    priceCop: 14000,
    imageAsset: 'assets/images/products/perro_cachorro.png',
    category: CatalogCategory.dogs,
    ingredientIds: ['mozzarella', 'huevo'],
  ),
  CatalogItem(
    id: 'trampa',
    name: 'La Trampa',
    tagline: 'Lo dulce es el anzuelo.',
    ingredients:
        'Salchicha americana, mozzarella, piña en trozos y tocineta crocante.',
    priceCop: 16000,
    imageAsset: 'assets/images/products/perro_trampa.png',
    category: CatalogCategory.dogs,
    ingredientIds: ['mozzarella', 'pina', 'tocineta'],
  ),
  CatalogItem(
    id: 'ave_presa',
    name: 'Ave de Presa',
    tagline: 'Cayó directo del corral.',
    ingredients:
        'Salchicha americana, pollo desmechado, maíz dulce, mozzarella '
        'y huevo de codorniz.',
    priceCop: 18000,
    imageAsset: 'assets/images/products/perro_ave_presa.png',
    category: CatalogCategory.dogs,
    ingredientIds: ['pollo', 'maiz', 'mozzarella', 'huevo'],
  ),
  CatalogItem(
    id: 'coyote',
    name: 'El Coyote',
    tagline: 'Cacería del desierto.',
    ingredients:
        'Salchicha americana, chile con carne, salsa de queso cheddar '
        'y maíz dulce.',
    priceCop: 18000,
    imageAsset: 'assets/images/products/perro_coyote.png',
    category: CatalogCategory.dogs,
    ingredientIds: ['chile', 'cheddar', 'maiz'],
  ),
  CatalogItem(
    id: 'carnicero',
    name: 'El Carnicero',
    tagline: 'Carne sobre carne, sin piedad.',
    ingredients:
        'Salchicha americana, salami, tocineta crocante y queso mozzarella.',
    priceCop: 17000,
    imageAsset: 'assets/images/products/perro_carnicero.png',
    category: CatalogCategory.dogs,
    ingredientIds: ['salami', 'tocineta', 'mozzarella'],
  ),
  depredadorItem,
  CatalogItem(
    id: 'manada_papas',
    name: 'Manada de Papas',
    tagline: 'Con las salsas de la casa.',
    ingredients: 'Papas a la francesa.',
    priceCop: 10000,
    imageAsset: 'assets/images/products/manada_papas.png',
    category: CatalogCategory.more,
    ingredientIds: [],
  ),
];

/// Conteo de productos por categoría (para la card del home).
int catalogCountOf(CatalogCategory c) =>
    catalogMockItems.where((i) => i.category == c).length;

/// Lookup por id para la ruta /home/category/:c/product/:productId.
CatalogItem catalogItemById(String id) => catalogMockItems.firstWhere(
  (i) => i.id == id,
  orElse: () => depredadorItem,
);
