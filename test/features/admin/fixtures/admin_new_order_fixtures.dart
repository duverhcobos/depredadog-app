import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_table.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/create_admin_order_use_case.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_tables_use_case.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_new_order_cubit.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_group.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_option.dart';
import 'package:depredadog_app/features/home/domain/failures/catalog_failure.dart';
import 'package:depredadog_app/features/home/domain/use_cases/get_catalog_menu_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

/// Fixtures de la comanda presencial (§042) — carta con
/// modifierGroups reales + mesas en los tres estados del contrato
/// (libre / ocupada con pedido vivo / inactiva) + los use cases
/// falsos que la pantalla y el cubit consumen.

/// Producto con grupos completos (misma forma del _cachorro del
/// detalle §019): pan y salchicha FIJOS (pan gratis, salchicha
/// esencial con precio de doble), mozzarella y cebolla removibles
/// incluidas, tocineta como adicional cobrada; toppings y salsas
/// gratis en grupos propios.
CatalogProduct newOrderCachorro({
  bool productAvailable = true,
  bool cebollaAvailable = true,
}) => CatalogProduct(
  id: 'p-cachorro',
  slug: 'cachorro',
  name: 'El Cachorro',
  tagline: 'El primer mordisco de la manada.',
  basePrice: 14000,
  imageUrl: null,
  isAvailable: productAvailable,
  isFeatured: false,
  isCombo: false,
  modifierGroups: [
    ModifierGroup(
      id: 'g-ing',
      slug: 'ingredients',
      name: 'Ingredientes',
      minSelect: 0,
      maxSelect: null,
      options: [
        const ModifierOption(
          id: 'o-pan',
          name: 'Pan artesanal',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: true,
        ),
        const ModifierOption(
          id: 'o-salchicha',
          name: 'Salchicha americana',
          extraPrice: 5000,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: true,
          isReplacementEligible: false,
          isReplaceable: false,
          isEssential: true,
        ),
        const ModifierOption(
          id: 'o-mozzarella',
          name: 'Queso mozzarella',
          extraPrice: 3500,
          isAvailable: true,
          isRemovable: true,
          includedByDefault: true,
        ),
        ModifierOption(
          id: 'o-cebolla',
          name: 'Cebolla',
          extraPrice: 0,
          isAvailable: cebollaAvailable,
          isRemovable: true,
          includedByDefault: true,
        ),
        const ModifierOption(
          id: 'o-tocineta',
          name: 'Tocineta crocante',
          extraPrice: 4000,
          isAvailable: true,
          isRemovable: true,
          includedByDefault: false,
        ),
      ],
    ),
    const ModifierGroup(
      id: 'g-top',
      slug: 'toppings',
      name: 'Toppings',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-ripio',
          name: 'Papa ripio',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
    const ModifierGroup(
      id: 'g-sau',
      slug: 'sauces',
      name: 'Salsas',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-pina',
          name: 'Piña',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
  ],
);

/// Segundo producto de otra "categoría" — sin personalización,
/// para el filtro de chips y las filas planas del ticket.
CatalogProduct newOrderPapas() => const CatalogProduct(
  id: 'p-papas',
  slug: 'manada-papas',
  name: 'Manada de papas',
  tagline: 'Crujientes para compartir.',
  basePrice: 10000,
  imageUrl: null,
  isAvailable: true,
  isFeatured: false,
  isCombo: false,
  modifierGroups: [],
);

/// Carta de dos categorías de la comanda.
List<CatalogCategory> newOrderCategories() => [
  CatalogCategory(
    id: 'cat-perros',
    slug: 'perros',
    name: 'Perros',
    products: [newOrderCachorro()],
  ),
  CatalogCategory(
    id: 'cat-mas',
    slug: 'mas',
    name: 'Más',
    products: [newOrderPapas()],
  ),
];

/// Mesas en los tres estados del contrato GET /admin/tables (§042):
/// libres (Mesa 1 y 2), ocupada con pedido vivo (Mesa 3 → #7) e
/// inactiva (Mesa 4 — viaja pero no acepta pedidos nuevos).
List<AdminTable> newOrderTables() => const [
  AdminTable(
    id: 't-1',
    label: 'Mesa 1',
    isActive: true,
    activeOrderNumber: null,
  ),
  AdminTable(
    id: 't-2',
    label: 'Mesa 2',
    isActive: true,
    activeOrderNumber: null,
  ),
  AdminTable(
    id: 't-3',
    label: 'Mesa 3',
    isActive: true,
    activeOrderNumber: 7,
  ),
  AdminTable(
    id: 't-4',
    label: 'Mesa 4',
    isActive: false,
    activeOrderNumber: null,
  ),
];

/// Pedido creado que el POST devuelve — presencial dine_in
/// confirmed con su consecutivo del día.
AdminOrder newOrderCreated() => AdminOrder(
  id: 'ord-nueva',
  channel: AdminOrderChannel.presencial,
  serviceType: AdminServiceType.dineIn,
  status: OrderStatus.confirmed,
  items: const [],
  paymentMethod: AdminPaymentMethod.cash,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 14000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 12, 40),
  tableLabel: 'Mesa 2',
  orderNumber: 8,
);

/// Use case falso de la carta (feature home — Either
/// CatalogFailure): el test lo arma con su propio when() o con el
/// stub de `buildAdminNewOrderCubit`.
class FakeGetCatalogMenuUseCase extends Mock
    implements GetCatalogMenuUseCase {}

/// Use case falso de las mesas (§042 — GET /admin/tables).
class FakeLoadAdminTablesUseCase extends Mock
    implements LoadAdminTablesUseCase {}

/// Use case falso del POST /admin/orders (§042) — recibe el
/// AdminNewOrderDraft completo (verify/capture sobre el borrador).
class FakeCreateAdminOrderUseCase extends Mock
    implements CreateAdminOrderUseCase {}

/// Cubit de la comanda listo para tests: carta + mesas stub con
/// las fixtures (o Left inyectado por pierna — un Left en
/// cualquiera tira la vista de error, §042) y el POST con Right
/// del pedido creado (o el failure inyectado).
AdminNewOrderCubit buildAdminNewOrderCubit({
  List<CatalogCategory>? categories,
  List<AdminTable>? tables,
  CatalogFailure? menuFailure,
  AdminFailure? tablesFailure,
  FakeCreateAdminOrderUseCase? createOrder,
}) {
  final menu = FakeGetCatalogMenuUseCase();
  final loadTables = FakeLoadAdminTablesUseCase();
  final create = createOrder ?? FakeCreateAdminOrderUseCase();
  when(() => menu.call()).thenAnswer(
    (_) async => menuFailure != null
        ? Left<CatalogFailure, List<CatalogCategory>>(menuFailure)
        : Right<CatalogFailure, List<CatalogCategory>>(
            categories ?? newOrderCategories(),
          ),
  );
  when(() => loadTables.call()).thenAnswer(
    (_) async => tablesFailure != null
        ? Left<AdminFailure, List<AdminTable>>(tablesFailure)
        : Right<AdminFailure, List<AdminTable>>(
            tables ?? newOrderTables(),
          ),
  );
  if (createOrder == null) {
    when(() => create.call(any())).thenAnswer(
      (_) async => Right<AdminFailure, AdminOrder>(newOrderCreated()),
    );
  }
  return AdminNewOrderCubit(
    getMenu: menu,
    loadTables: loadTables,
    createOrder: create,
  );
}
