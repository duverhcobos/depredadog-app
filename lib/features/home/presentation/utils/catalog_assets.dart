/// Mapeo slug → asset local mientras `imageUrl` llega null
/// (pendientes backend/006 — imágenes reales). Cuando el backend sirva
/// fotos, ProductImage prefiere `imageUrl` y estos assets quedan de
/// fallback por si falla la red o el slug no tiene foto remota.
abstract final class CatalogAssets {
  static const _productAssets = <String, String>{
    'depredador': 'assets/images/products/perro_depredador.png',
    'cachorro': 'assets/images/products/perro_cachorro.png',
    'trampa': 'assets/images/products/perro_trampa.png',
    'ave-presa': 'assets/images/products/perro_ave_presa.png',
    'coyote': 'assets/images/products/perro_coyote.png',
    'carnicero': 'assets/images/products/perro_carnicero.png',
    'manada-papas': 'assets/images/products/manada_papas.png',
    // & Más de la carta real — arte de papas del mock sirve de
    // placeholder hasta las fotos reales (pendientes backend/006).
    'papas-francesa': 'assets/images/products/manada_papas.png',
    'bacon-cheese-fries': 'assets/images/products/manada_papas.png',
    'dorisalvaje': 'assets/images/products/manada_papas.png',
    // Bebidas — la ilustración de la categoría cubre toda la línea.
    'coca-cola-400': 'assets/images/products/cat_bebidas.png',
    'coca-cola-1l': 'assets/images/products/cat_bebidas.png',
    'coca-cola-15l': 'assets/images/products/cat_bebidas.png',
    'coca-cola-3l': 'assets/images/products/cat_bebidas.png',
    'pony-malta-330': 'assets/images/products/cat_bebidas.png',
    'pony-malta-1l': 'assets/images/products/cat_bebidas.png',
    'pony-malta-15l': 'assets/images/products/cat_bebidas.png',
    'big-cola-400': 'assets/images/products/cat_bebidas.png',
    'big-cola-1l': 'assets/images/products/cat_bebidas.png',
    'big-cola-175l': 'assets/images/products/cat_bebidas.png',
    'big-cola-3l': 'assets/images/products/cat_bebidas.png',
    'jugo-hit-500': 'assets/images/products/cat_bebidas.png',
    'agua-botella': 'assets/images/products/cat_bebidas.png',
  };

  static const _categoryCovers = <String, String>{
    'perros': 'assets/images/products/perro_depredador.png',
    'mas': 'assets/images/products/manada_papas.png',
    'y-mas': 'assets/images/products/manada_papas.png',
    'bebidas': 'assets/images/products/cat_bebidas.png',
    'combos': 'assets/images/products/cat_combos.png',
  };

  static const _fallback = 'assets/images/products/perro_depredador.png';

  static String productAsset(String slug) => _productAssets[slug] ?? _fallback;

  static String categoryCover(String slug) =>
      _categoryCovers[slug] ?? _fallback;
}
