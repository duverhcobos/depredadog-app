import 'package:equatable/equatable.dart';

import 'catalog_product.dart';

/// Categoría del menú (§019) — dinámica del backend: el `name` es dato
/// de negocio (igual que los nombres de producto), `slug` es la clave
/// de ruta y del cover local.
class CatalogCategory extends Equatable {
  const CatalogCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.products,
  });

  final String id;
  final String slug;
  final String name;
  final List<CatalogProduct> products;

  // Igualdad por valor completa — ver CatalogProduct.props.
  @override
  List<Object?> get props => [id, slug, name, products];
}
