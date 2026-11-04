import '../../domain/entities/catalog_category.dart';
import '../../domain/entities/catalog_product.dart';
import '../../domain/entities/modifier_group.dart';
import '../../domain/entities/modifier_option.dart';

/// SOLID (SRP): las únicas clases que conocen el JSON de GET /catalog.
/// Convención del repo: Model extends Entity + factory fromJson
/// (igual que UserModel). Los precios llegan numéricos (numeric→number
/// del transformer) — se castea a int vía num.
class ModifierOptionModel extends ModifierOption {
  const ModifierOptionModel({
    required super.id,
    required super.name,
    required super.extraPrice,
    required super.isAvailable,
    required super.isRemovable,
    required super.includedByDefault,
    super.isReplaceable,
    super.isReplacementEligible,
    super.isEssential,
  });

  factory ModifierOptionModel.fromJson(Map<String, dynamic> json) =>
      ModifierOptionModel(
        id: json['id'] as String,
        name: json['name'] as String,
        extraPrice: (json['extraPrice'] as num).toInt(),
        isAvailable: json['isAvailable'] as bool,
        isRemovable: json['isRemovable'] as bool,
        includedByDefault: json['includedByDefault'] as bool,
        // Default true si el campo no viaja (compat defensiva).
        isReplaceable: (json['isReplaceable'] as bool?) ?? true,
        isReplacementEligible: (json['isReplacementEligible'] as bool?) ?? true,
        isEssential: (json['isEssential'] as bool?) ?? false,
      );
}

class ModifierGroupModel extends ModifierGroup {
  const ModifierGroupModel({
    required super.id,
    required super.slug,
    required super.name,
    required super.minSelect,
    required super.maxSelect,
    required super.options,
  });

  factory ModifierGroupModel.fromJson(Map<String, dynamic> json) =>
      ModifierGroupModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        minSelect: (json['minSelect'] as num).toInt(),
        maxSelect: (json['maxSelect'] as num?)?.toInt(),
        options: (json['options'] as List<dynamic>)
            .map((o) => ModifierOptionModel.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class CatalogProductModel extends CatalogProduct {
  const CatalogProductModel({
    required super.id,
    required super.slug,
    required super.name,
    required super.tagline,
    required super.basePrice,
    required super.imageUrl,
    required super.isAvailable,
    required super.isFeatured,
    required super.isCombo,
    required super.modifierGroups,
  });

  factory CatalogProductModel.fromJson(Map<String, dynamic> json) =>
      CatalogProductModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        tagline: (json['description'] as String?) ?? '',
        basePrice: (json['basePrice'] as num).toInt(),
        imageUrl: json['imageUrl'] as String?,
        isAvailable: json['isAvailable'] as bool,
        isFeatured: json['isFeatured'] as bool,
        isCombo: json['isCombo'] as bool,
        modifierGroups: (json['modifierGroups'] as List<dynamic>)
            .map((g) => ModifierGroupModel.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

class CatalogCategoryModel extends CatalogCategory {
  const CatalogCategoryModel({
    required super.id,
    required super.slug,
    required super.name,
    required super.products,
  });

  factory CatalogCategoryModel.fromJson(Map<String, dynamic> json) =>
      CatalogCategoryModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        products: (json['products'] as List<dynamic>)
            .map((p) => CatalogProductModel.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
