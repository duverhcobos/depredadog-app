import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/home/data/models/catalog_models.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_group.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_option.dart';

void main() {
  group('CatalogCategoryModel.fromJson', () {
    test('parsea el árbol completo del contrato GET /catalog '
        '(categoría → producto → grupo → opción)', () {
      final json = <String, dynamic>{
        'id': 'cat-1',
        'slug': 'perros',
        'name': 'Perros',
        'sortOrder': 1,
        'products': [
          <String, dynamic>{
            'id': 'prod-1',
            'slug': 'depredador',
            'name': 'El Depredador',
            'description': 'El alfa come de todo.',
            'basePrice': 25000,
            'imageUrl': null,
            'isAvailable': true,
            'isFeatured': true,
            'isCombo': false,
            'sortOrder': 1,
            'modifierGroups': [
              <String, dynamic>{
                'id': 'grp-1',
                'slug': 'ingredients',
                'name': 'Ingredientes',
                'minSelect': 0,
                'maxSelect': null,
                'options': [
                  <String, dynamic>{
                    'id': 'opt-1',
                    'name': 'Salchicha americana',
                    // numeric del backend → llega como num (puede ser
                    // double) y el model lo normaliza a int.
                    'extraPrice': 5000.0,
                    'isAvailable': true,
                    'isRemovable': false,
                    'includedByDefault': true,
                    'isReplaceable': false,
                    'isReplacementEligible': false,
                    'isEssential': true,
                    'sortOrder': 1,
                  },
                ],
              },
            ],
          },
        ],
      };

      final category = CatalogCategoryModel.fromJson(json);

      expect(category.id, 'cat-1');
      expect(category.slug, 'perros');
      expect(category.name, 'Perros');
      expect(category.products, hasLength(1));

      final product = category.products.single;
      expect(product.id, 'prod-1');
      expect(product.slug, 'depredador');
      expect(product.name, 'El Depredador');
      // description del contrato → tagline de la entidad.
      expect(product.tagline, 'El alfa come de todo.');
      expect(product.basePrice, 25000);
      expect(product.basePrice, isA<int>());
      expect(product.imageUrl, isNull);
      expect(product.isAvailable, isTrue);
      expect(product.isFeatured, isTrue);
      expect(product.isCombo, isFalse);
      expect(product.modifierGroups, hasLength(1));

      final group = product.modifierGroups.single;
      expect(group.slug, 'ingredients');
      expect(group.minSelect, 0);
      expect(group.maxSelect, isNull);
      expect(group.options, hasLength(1));

      final option = group.options.single;
      expect(option.id, 'opt-1');
      expect(option.name, 'Salchicha americana');
      expect(option.extraPrice, 5000);
      expect(option.extraPrice, isA<int>());
      expect(option.isAvailable, isTrue);
      expect(option.isRemovable, isFalse);
      expect(option.includedByDefault, isTrue);
      // Flags del cambio gratis (§019) — el false viaja, no cae en
      // el default true.
      expect(option.isReplaceable, isFalse);
      expect(option.isReplacementEligible, isFalse);
      expect(option.isEssential, isTrue);
    });

    test('description null → tagline vacío', () {
      final product = CatalogProductModel.fromJson(<String, dynamic>{
        'id': 'prod-2',
        'slug': 'manada-papas',
        'name': 'Manada de Papas',
        'description': null,
        'basePrice': 10000,
        'imageUrl': null,
        'isAvailable': true,
        'isFeatured': false,
        'isCombo': false,
        'sortOrder': 1,
        'modifierGroups': const [],
      });

      expect(product.tagline, '');
    });

    test('producto con modifierGroups: [] → lista vacía sin explotar', () {
      final product = CatalogProductModel.fromJson(<String, dynamic>{
        'id': 'prod-3',
        'slug': 'limonada',
        'name': 'Limonada',
        'description': 'Fresca.',
        'basePrice': 6000,
        'imageUrl': null,
        'isAvailable': true,
        'isFeatured': false,
        'isCombo': false,
        'sortOrder': 2,
        'modifierGroups': const [],
      });

      expect(product.modifierGroups, isEmpty);
      // Los helpers de dominio también aguantan el producto sin grupos.
      expect(product.removableIngredients, isEmpty);
      expect(product.additionalOptions, isEmpty);
      expect(product.toppingOptions, isEmpty);
      expect(product.sauceOptions, isEmpty);
      expect(product.ingredientsSummary, '');
    });
  });

  group('CatalogProduct.additionalOptions (§045)', () {
    ModifierOption opt(
      String id, {
      required bool included,
      required int extraPrice,
      bool removable = true,
    }) => ModifierOption(
      id: id,
      name: id,
      extraPrice: extraPrice,
      isAvailable: true,
      isRemovable: removable,
      includedByDefault: included,
    );

    CatalogProduct product(List<ModifierOption> options) => CatalogProduct(
      id: 'p-1',
      slug: 'perro',
      name: 'Perro',
      tagline: '',
      basePrice: 10000,
      imageUrl: null,
      isAvailable: true,
      isFeatured: false,
      isCombo: false,
      modifierGroups: [
        ModifierGroup(
          id: 'g-ing',
          slug: 'ingredients',
          name: 'Ingredientes',
          minSelect: 0,
          maxSelect: null,
          options: options,
        ),
      ],
    );

    test('incluida + removible + extraPrice > 0 → SÍ entra '
        '(repetir cobrado, §045)', () {
      final p = product([
        opt('o-moza', included: true, extraPrice: 3500),
      ]);
      expect(p.additionalOptions.map((o) => o.id), ['o-moza']);
    });

    test('incluida + extraPrice == 0 → NO entra (no se vende suelta)', () {
      final p = product([opt('o-pan', included: true, extraPrice: 0)]);
      expect(p.additionalOptions, isEmpty);
    });

    test('no incluida → SÍ entra, con o sin precio', () {
      final p = product([
        opt('o-tocineta', included: false, extraPrice: 4000),
        opt('o-gratis', included: false, extraPrice: 0),
      ]);
      expect(p.additionalOptions.map((o) => o.id), [
        'o-tocineta',
        'o-gratis',
      ]);
    });
  });
}
