# Propuesta 019 — Integración `GET /catalog` (home/lista/detalle)

Reemplaza `catalog_mock.dart` por el menú real del backend
(`GET /catalog`, JWT — ya implementado, propuesta backend 007-009).
Fase 2 del screen-first-workflow: integración del **único endpoint**
del módulo de catálogo.

## Decisiones del usuario (encuesta previa)

- `slug` en products del backend (propuesta backend 009) → clave para
  assets locales y segmento de ruta del detalle.
- Producto `isAvailable=false` → **tag "Agotado", sin tap** — la
  card NO se atenúa (en la revisión visual el usuario descartó la
  translucidez: "con el botón Agotado basta"). El agotado efectivo
  (`isSellable`) también tumba por **insumo esencial**: ingrediente
  incluido `isEssential` agotado (salchicha/pan — flag del backend
  §011) apaga el producto entero sin que el dueño lo toque.
- Opción `isAvailable=false` → **gris deshabilitada** en las secciones
  (Opacity 0.45 aprobada) + **X en círculo rojo** (`cancel_rounded`
  error) en vez del check — también decidido en la revisión visual.
- **Cambio gratis** (regla del usuario): ingrediente incluido agotado
  se puede cambiar por UN adicional sin costo — icono swap_horiz junto
  a la X SOLO si `isReplaceable` (agotado no reemplazable como la
  salchicha = solo X, decisión del usuario) despliega (AnimatedSize
  ~180ms) los adicionales disponibles **elegibles**
  (`isReplacementEligible` — la salchicha doble nunca se regala)
  como OptionRows sin etiqueta (alterna a chevron de colapsar); elegir una
  opción colapsa el picker y el reemplazo queda como **fila propia bajo
  el agotado** — sangrada + gancho ↳ para leerla como hija del
  ingrediente (clave con varios agotados), colores de fila activa —
  tocarla (o el icono) reabre para cambiarla; solo el agotado habilita
  el cambio, 1:1. **Unicidad del candidato** (bug reportado en la
  revisión visual): un adicional ya tomado como reemplazo por OTRO
  agotado no se lista en su picker — la exclusión es entre agotadas
  (la propia sigue listada); si no queda ningún candidato libre el ↔
  se oculta en vez de abrir un picker vacío.
- Categorías **dinámicas desde el backend** (el enum `CatalogCategory`
  muere con el mock; el nombre viene del dato, igual que productos).

## Estrategia de frescura (ya acordada con el usuario)

- `CatalogCubit` lazySingleton compartido en el shell → carga al entrar
  al área autenticada.
- **Refresh silencioso al entrar a cada pantalla** (home, lista,
  detalle): re-pide `/catalog` manteniendo los datos visibles (sin
  flicker); si falla, se queda con el caché y solo loggea. La
  disponibilidad real se revalida al crear la orden (módulo orders).

## Reglas de dominio (del modelo aprobado §018)

- "¿Se le quita algo?" = opciones del grupo `ingredients` con
  `includedByDefault && isRemovable`.
- "¿Le agregamos algo más?" = opciones del grupo `ingredients` con
  `!includedByDefault` **o** (`includedByDefault && !isRemovable &&
  extraPrice > 0`) — esta segunda rama preserva la **doble salchicha**
  (incluida y fija, pero cobrada si se repite; el pan queda fuera porque
  su extraPrice es 0).
- Toppings/salsas = opciones de sus grupos por slug.
- Pan y salchicha fijos: `includedByDefault && !isRemovable` no aparece
  en "quitar" (pan tampoco en adicionales por la regla de arriba).
- `ingredientsSummary` = nombres de los defaults del grupo ingredients
  unidos "A, B y C." — reemplaza el texto `ingredients` del mock.
- Hero "El de la casa" = producto con `isFeatured` en la categoría.
- Total = `basePrice` + Σ `extraPrice` de adicionales seleccionados.

## Contrato consumido (backend doc + e2e)

`GET /catalog` → `{ "categories": [ { id, slug, name, sortOrder,
products: [ { id, slug, name, description, basePrice, imageUrl,
isAvailable, isFeatured, isCombo, sortOrder, modifierGroups: [ { id,
slug, name, minSelect, maxSelect, options: [ { id, name, extraPrice,
isAvailable, isRemovable, includedByDefault, sortOrder } ] } ] } ] } ] }`
— `description` llega como tagline; `imageUrl` hoy null → asset por slug.

---

## Resumen de cambios

| Archivo | Acción |
|---|---|
| `lib/features/home/domain/entities/modifier_option.dart` | **NUEVO** — entidad de opción |
| `lib/features/home/domain/entities/modifier_group.dart` | **NUEVO** — grupo + slugs estables |
| `lib/features/home/domain/entities/catalog_product.dart` | **NUEVO** — producto + helpers de dominio |
| `lib/features/home/domain/entities/catalog_category.dart` | **NUEVO** — categoría |
| `lib/features/home/domain/failures/catalog_failure.dart` | **NUEVO** — jerarquía de fallos |
| `lib/features/home/domain/repositories/i_catalog_repository.dart` | **NUEVO** — contrato |
| `lib/features/home/domain/use_cases/get_catalog_menu_use_case.dart` | **NUEVO** — use case |
| `lib/features/home/data/models/catalog_models.dart` | **NUEVO** — 4 models fromJson |
| `lib/features/home/data/datasources/interfaces/i_catalog_remote_datasource.dart` | **NUEVO** — puerto |
| `lib/features/home/data/datasources/implementations/catalog_remote_datasource_impl.dart` | **NUEVO** — GET /catalog |
| `lib/features/home/data/repositories/catalog_repository_impl.dart` | **NUEVO** — Either mapping |
| `lib/features/home/presentation/cubit/catalog_state.dart` | **NUEVO** — estado |
| `lib/features/home/presentation/cubit/catalog_cubit.dart` | **NUEVO** — cubit + dedupe/refresh |
| `lib/features/home/presentation/utils/catalog_assets.dart` | **NUEVO** — slug→asset |
| `lib/features/home/presentation/utils/format_cop.dart` | **NUEVO** — movido del mock |
| `lib/features/home/presentation/widgets/catalog_states.dart` | **NUEVO** — loading/error compartidos |
| `lib/core/di/setup_di.dart` | registros catalog |
| `lib/core/routes/app_router.dart` | BlocProvider del cubit + params slug |
| `lib/features/home/presentation/screens/home_screen.dart` | reescritura — BlocBuilder + categorías dinámicas |
| `lib/features/home/presentation/screens/category_products_screen.dart` | slug + BlocBuilder + hero featured |
| `lib/features/home/presentation/screens/product_detail_screen.dart` | slug + BlocBuilder + grupos reales |
| `lib/features/home/presentation/widgets/category_card.dart` | entidad dominio |
| `lib/features/home/presentation/widgets/product_card.dart` | entidad + agotado |
| `lib/features/home/presentation/widgets/hero_product_card.dart` | entidad + agotado |
| `lib/features/home/presentation/widgets/product_image.dart` | imageUrl opcional |
| `lib/features/home/presentation/widgets/customization_section.dart` | `enabled` en rows/chip |
| `lib/l10n/app_es.arb` | keys nuevas; quitar 4 de categoría |
| `lib/features/home/presentation/data/catalog_mock.dart` | **ELIMINADO** |
| `test/features/home/presentation/cubit/catalog_cubit_test.dart` | **NUEVO** |
| `test/features/home/data/repositories/catalog_repository_impl_test.dart` | **NUEVO** |
| `test/features/home/data/models/catalog_models_test.dart` | **NUEVO** |
| `test/features/home/presentation/category_products_screen_test.dart` | reescritura con MockCubit |
| `test/features/home/presentation/product_detail_screen_test.dart` | reescritura con MockCubit |

---

## 1. Entidades de dominio (archivos nuevos)

### `lib/features/home/domain/entities/modifier_option.dart`

```dart
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

  @override
  List<Object?> get props => [id];
}
```

### `lib/features/home/domain/entities/modifier_group.dart`

```dart
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

  @override
  List<Object?> get props => [id, slug];
}
```

### `lib/features/home/domain/entities/catalog_product.dart`

```dart
import 'package:equatable/equatable.dart';

import 'modifier_group.dart';
import 'modifier_option.dart';

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

  /// "¿Se le quita algo?": incluidos por defecto Y removibles (pan y
  /// salchicha quedan fuera — fijos).
  List<ModifierOption> get removableIngredients =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where((o) => o.includedByDefault && o.isRemovable)
          .toList();

  /// "¿Le agregamos algo más?": las que NO vienen por defecto, más los
  /// fijos con precio (doble salchicha — incluida/no removible pero
  /// cobrada si se repite; el pan no entra porque su precio es 0).
  List<ModifierOption> get additionalOptions =>
      (groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
              const <ModifierOption>[])
          .where(
            (o) =>
                !o.includedByDefault ||
                (!o.isRemovable && o.extraPrice > 0),
          )
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

  @override
  List<Object?> get props => [id];
}
```

### `lib/features/home/domain/entities/catalog_category.dart`

```dart
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

  @override
  List<Object?> get props => [id, slug];
}
```

### `lib/features/home/domain/failures/catalog_failure.dart`

```dart
import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo del catálogo — el
/// repository impl es el único que traduce NetworkException; la UI solo
/// hace pattern-matching para elegir el mensaje (misma convención que
/// AuthFailure).
sealed class CatalogFailure extends Equatable {
  const CatalogFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad (INetworkInfo o timeout de conexión).
class CatalogOfflineFailure extends CatalogFailure {
  const CatalogOfflineFailure();
}

/// Cualquier otro error (5xx, timeout, parseo, inesperado) — conserva el
/// mensaje solo para logging; la UI muestra texto genérico propio.
class CatalogServerFailure extends CatalogFailure {
  const CatalogServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

### `lib/features/home/domain/repositories/i_catalog_repository.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/catalog_category.dart';
import '../failures/catalog_failure.dart';

/// SOLID (DIP): contrato del menú — la presentación no conoce HTTP.
abstract class ICatalogRepository {
  /// GET /catalog — el menú completo en un solo documento (bounded).
  Future<Either<CatalogFailure, List<CatalogCategory>>> getMenu();
}
```

### `lib/features/home/domain/use_cases/get_catalog_menu_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/catalog_category.dart';
import '../failures/catalog_failure.dart';
import '../repositories/i_catalog_repository.dart';

/// SOLID (SRP): una acción — traer el menú completo.
class GetCatalogMenuUseCase {
  const GetCatalogMenuUseCase(this._repository);

  final ICatalogRepository _repository;

  Future<Either<CatalogFailure, List<CatalogCategory>>> call() =>
      _repository.getMenu();
}
```

## 2. Capa data (archivos nuevos)

### `lib/features/home/data/models/catalog_models.dart`

```dart
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
  });

  factory ModifierOptionModel.fromJson(Map<String, dynamic> json) =>
      ModifierOptionModel(
        id: json['id'] as String,
        name: json['name'] as String,
        extraPrice: (json['extraPrice'] as num).toInt(),
        isAvailable: json['isAvailable'] as bool,
        isRemovable: json['isRemovable'] as bool,
        includedByDefault: json['includedByDefault'] as bool,
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
            .map(
              (o) => ModifierOptionModel.fromJson(
                o as Map<String, dynamic>,
              ),
            )
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
            .map(
              (g) => ModifierGroupModel.fromJson(
                g as Map<String, dynamic>,
              ),
            )
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
            .map(
              (p) => CatalogProductModel.fromJson(
                p as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}
```

### `lib/features/home/data/datasources/interfaces/i_catalog_remote_datasource.dart`

```dart
import '../../models/catalog_models.dart';

/// SOLID (DIP): puerto HTTP del catálogo — devuelve models o lanza
/// NetworkException; los callers nunca ven Dio.
abstract class ICatalogRemoteDataSource {
  /// GET /catalog — Bearer lo adjunta el AuthInterceptor.
  Future<List<CatalogCategoryModel>> fetchMenu();
}
```

### `lib/features/home/data/datasources/implementations/catalog_remote_datasource_impl.dart`

```dart
import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/catalog_models.dart';
import '../interfaces/i_catalog_remote_datasource.dart';

/// SOLID (SRP): solo llama GET /catalog y parsea — el Bearer lo pone el
/// AuthInterceptor, los errores los traduce el repository.
class CatalogRemoteDataSourceImpl implements ICatalogRemoteDataSource {
  const CatalogRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<List<CatalogCategoryModel>> fetchMenu() async {
    final response = await _networkService.get('/catalog');
    final categories =
        (response as Map<String, dynamic>)['categories'] as List<dynamic>;
    return categories
        .map(
          (c) => CatalogCategoryModel.fromJson(c as Map<String, dynamic>),
        )
        .toList();
  }
}
```

### `lib/features/home/data/repositories/catalog_repository_impl.dart`

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/failures/catalog_failure.dart';
import '../../domain/repositories/i_catalog_repository.dart';
import '../datasources/interfaces/i_catalog_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → CatalogFailure (la UI nunca ve excepciones crudas).
class CatalogRepositoryImpl implements ICatalogRepository {
  const CatalogRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final ICatalogRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<CatalogFailure, List<CatalogCategory>>> getMenu() async {
    if (!await _networkInfo.isConnected) {
      return const Left(CatalogOfflineFailure());
    }
    try {
      final menu = await _remoteDataSource.fetchMenu();
      return Right(menu);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      // Red de seguridad (misma que auth): un 200 malformado (cast del
      // datasource) no es NetworkException — sin este catch la UI
      // quedaría en loading para siempre.
      return Left(CatalogServerFailure(e.toString()));
    }
  }

  CatalogFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const CatalogOfflineFailure();
    // 401 residual (si el refresh definitivo falló, TokenRefreshService
    // ya expulsó la sesión → el guard navega solo; esto es defensivo),
    // 429, 5xx, timeouts → genérico con retry.
    return CatalogServerFailure(e.message);
  }
}
```

## 3. Cubit (archivos nuevos)

### `lib/features/home/presentation/cubit/catalog_state.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/catalog_category.dart';
import '../../domain/failures/catalog_failure.dart';

enum CatalogStatus { initial, loading, success, error }

/// SOLID (SRP): estado del menú — las pantallas derivan vistas; el
/// refresh silencioso mantiene `categories` mientras re-pide (status no
/// vuelve a loading si ya hay datos).
class CatalogState extends Equatable {
  const CatalogState({
    required this.status,
    required this.categories,
    this.failure,
  });

  const CatalogState.initial()
    : status = CatalogStatus.initial,
      categories = const [],
      failure = null;

  final CatalogStatus status;
  final List<CatalogCategory> categories;
  final CatalogFailure? failure;

  @override
  List<Object?> get props => [status, categories, failure];
}
```

### `lib/features/home/presentation/cubit/catalog_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/interfaces/i_logger_service.dart';
import '../../domain/use_cases/get_catalog_menu_use_case.dart';
import 'catalog_state.dart';

/// SOLID (SRP): fuente única del menú para las 3 pantallas de catálogo.
/// lazySingleton en el shell — la misma instancia sirve home, lista y
/// detalle (no se re-pide por pantalla ni se duplica el caché).
///
/// `load()`: primera carga (o después de un error) — muestra loading
/// solo cuando no hay datos. `refresh()`: re-pide al entrar a cada
/// pantalla — SILENCIOSO: con datos ya visibles no hay flicker, y si
/// falla se queda con el caché (la disponibilidad real se revalida al
/// crear la orden).
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit({
    required GetCatalogMenuUseCase getCatalogMenuUseCase,
    required ILoggerService logger,
  }) : _getMenu = getCatalogMenuUseCase,
       _logger = logger,
       super(const CatalogState.initial());

  final GetCatalogMenuUseCase _getMenu;
  final ILoggerService _logger;

  Future<void>? _inFlight;

  /// Carga inicial. No-op si ya hay datos (salvo forceRefresh).
  Future<void> load({bool forceRefresh = false}) =>
      _run(forceRefresh: forceRefresh);

  /// Re-pide al entrar a una pantalla — siempre fuerza el fetch,
  /// deduplicado con cualquier otra llamada en vuelo.
  Future<void> refresh() => _run(forceRefresh: true);

  Future<void> _run({required bool forceRefresh}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (!forceRefresh && state.status == CatalogStatus.success) {
      return Future.value();
    }
    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    if (state.categories.isEmpty) {
      emit(
        const CatalogState(
          status: CatalogStatus.loading,
          categories: [],
        ),
      );
    }
    final result = await _getMenu();
    result.fold(
      (failure) {
        if (state.categories.isNotEmpty) {
          // Refresh falló con datos viejos → se queda con ellos (solo
          // log; nada de toast ni error view — UX acordada).
          _logger.warn(
            'Catalog refresh failed, keeping cached menu',
            'CatalogCubit',
          );
          return;
        }
        emit(
          CatalogState(
            status: CatalogStatus.error,
            categories: const [],
            failure: failure,
          ),
        );
      },
      (menu) => emit(
        CatalogState(status: CatalogStatus.success, categories: menu),
      ),
    );
  }
}
```

## 4. Utils de presentación (archivos nuevos)

### `lib/features/home/presentation/utils/format_cop.dart`

```dart
/// 14000 → "$14.000" (COP con separador de miles por punto).
/// Movido del mock §017/018 — acepta num porque los precios del
/// backend llegan como numérico.
String formatCop(num price) {
  final s = price.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}
```

### `lib/features/home/presentation/utils/catalog_assets.dart`

```dart
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
  };

  static const _categoryCovers = <String, String>{
    'perros': 'assets/images/products/perro_depredador.png',
    'mas': 'assets/images/products/manada_papas.png',
    'bebidas': 'assets/images/products/cat_bebidas.png',
    'combos': 'assets/images/products/cat_combos.png',
  };

  static const _fallback = 'assets/images/products/perro_depredador.png';

  static String productAsset(String slug) =>
      _productAssets[slug] ?? _fallback;

  static String categoryCover(String slug) =>
      _categoryCovers[slug] ?? _fallback;
}
```

### `lib/features/home/presentation/widgets/catalog_states.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Estados de carga/error compartidos por las pantallas de catálogo
/// (§019). Los estados CON datos visibles nunca caen acá — el refresh
/// silencioso no tumba el contenido.
class CatalogLoadingView extends StatelessWidget {
  const CatalogLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Error sin caché: ícono + título + subtítulo + retry. El usuario ve
/// esto solo cuando la PRIMERA carga falla (sin datos que mostrar).
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.catalogLoadErrorTitle,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.catalogLoadErrorSubtitle,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.catalogRetry),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 5. DI (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes (bloque de imports de auth, agregar al grupo):**

```dart
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
import '../auth/auth_session.dart';
```

**Después:**

```dart
import '../../features/auth/presentation/cubit/verify_email_cubit.dart';
import '../../features/home/data/datasources/implementations/catalog_remote_datasource_impl.dart';
import '../../features/home/data/datasources/interfaces/i_catalog_remote_datasource.dart';
import '../../features/home/data/repositories/catalog_repository_impl.dart';
import '../../features/home/domain/repositories/i_catalog_repository.dart';
import '../../features/home/domain/use_cases/get_catalog_menu_use_case.dart';
import '../../features/home/presentation/cubit/catalog_cubit.dart';
import '../auth/auth_session.dart';
```

**Antes (al final de Repositories auth, antes de `// --- Use Cases (auth) ---`):**

```dart
  // --- Use Cases (auth) ---
```

**Después:**

```dart
  // --- Catálogo (propuesta 019) ---
  locator.registerLazySingleton<ICatalogRemoteDataSource>(
    () => CatalogRemoteDataSourceImpl(
      networkService: locator<INetworkService>(),
    ),
  );
  locator.registerLazySingleton<ICatalogRepository>(
    () => CatalogRepositoryImpl(
      remoteDataSource: locator<ICatalogRemoteDataSource>(),
      networkInfo: locator<INetworkInfo>(),
    ),
  );
  locator.registerLazySingleton<GetCatalogMenuUseCase>(
    () => GetCatalogMenuUseCase(locator<ICatalogRepository>()),
  );
  // lazySingleton (regla 9 SOLID): el menú es estado persistente
  // compartido entre las 3 pantallas — una sola instancia.
  locator.registerLazySingleton<CatalogCubit>(
    () => CatalogCubit(
      getCatalogMenuUseCase: locator<GetCatalogMenuUseCase>(),
      logger: locator<ILoggerService>(),
    ),
  );

  // --- Use Cases (auth) ---
```

## 6. Router (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes (imports):**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
```

**Después:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
```

**Antes:**

```dart
import '../../features/home/presentation/data/catalog_mock.dart';
import '../../features/home/presentation/screens/category_products_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/product_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../layout/app_shell_layout.dart';
```

**Después:**

```dart
import '../../features/home/presentation/cubit/catalog_cubit.dart';
import '../../features/home/presentation/screens/category_products_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/product_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../di/setup_di.dart';
import '../layout/app_shell_layout.dart';
```

**Antes:**

```dart
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellLayout(shell: navigationShell),
```

**Después:**

```dart
      StatefulShellRoute.indexedStack(
        // CatalogCubit sobre el shell (propuesta 019): las 3 pantallas
        // de catálogo (home, lista, detalle — rutas hijas dentro de la
        // branch) comparten la misma instancia y su caché. load() es
        // no-op si ya hay datos — el refresh real lo gatilla cada
        // pantalla al entrar.
        builder: (context, state, navigationShell) => BlocProvider.value(
          value: locator<CatalogCubit>()..load(),
          child: AppShellLayout(shell: navigationShell),
        ),
```

**Antes:**

```dart
                  GoRoute(
                    path: 'category/:categoryId',
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      CategoryProductsScreen(
                        category: CatalogCategoryX.fromSegment(
                          state.pathParameters['categoryId'] ?? '',
                        ),
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'product/:productId',
                        pageBuilder: (context, state) =>
                            CustomTransitions.slideUp(
                              state,
                              ProductDetailScreen(
                                item: catalogItemById(
                                  state.pathParameters['productId'] ?? '',
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
```

**Después:**

```dart
                  GoRoute(
                    path: 'category/:categorySlug',
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      CategoryProductsScreen(
                        categorySlug:
                            state.pathParameters['categorySlug'] ?? '',
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'product/:productSlug',
                        pageBuilder: (context, state) =>
                            CustomTransitions.slideUp(
                              state,
                              ProductDetailScreen(
                                productSlug:
                                    state.pathParameters['productSlug'] ??
                                    '',
                              ),
                            ),
                      ),
                    ],
                  ),
```

## 7. HomeScreen (archivo existente — reescritura)

**Ruta:** `lib/features/home/presentation/screens/home_screen.dart`

Reemplazo completo:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../widgets/catalog_states.dart';
import '../widgets/category_card.dart';
import '../widgets/promo_banner.dart';
import '../widgets/signature_strip.dart';

/// Home — selector de categorías (§017 + integración §019). Firma de la
/// referencia del usuario: franja MOSTAZA al 40% del ancho; las cards de
/// categoría y la promo nacen dentro de ella y desbordan hacia el
/// negro. Las categorías ahora son DINÁMICAS del backend (decisión del
/// usuario) — una nueva aparece sola sin release.
///
/// Datos: CatalogCubit compartido del shell. Al entrar dispara
/// refresh() silencioso — el menú visible no parpadea; la primera carga
/// muestra loading/error con retry.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CatalogCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, state) {
              if (state.categories.isEmpty) {
                if (state.status == CatalogStatus.error) {
                  return CatalogErrorView(
                    onRetry: () =>
                        context.read<CatalogCubit>().refresh(),
                  );
                }
                return const CatalogLoadingView();
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // El aire que ocupaba la franja de estado — el
                  // carrusel respira bajo el header (§017).
                  const SizedBox(height: 36),
                  const PromoBanner(),
                  const SizedBox(height: 8),
                  for (final category in state.categories)
                    CategoryCard(category: category),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

## 8. CategoryProductsScreen (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/category_products_screen.dart`

La pantalla cambia a StatefulWidget (refresh al entrar) + recibe
`categorySlug` + BlocBuilder que resuelve la categoría del estado. El
bloque del "cupo fantasma" y la flecha quedan IGUALES — solo cambian:

**Antes (imports + firma):**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import '../widgets/hero_product_card.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

/// Lista de productos de una categoría ...
class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({required this.category, super.key});

  final CatalogCategory category;

  String _label(AppLocalizations l10n) => switch (category) {
    CatalogCategory.dogs => l10n.catalogCategoryDogs,
    CatalogCategory.more => l10n.catalogCategoryMore,
    CatalogCategory.drinks => l10n.catalogCategoryDrinks,
    CatalogCategory.combos => l10n.catalogCategoryCombos,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = catalogMockItems
        .where((i) => i.category == category)
        .toList();
```

**Después:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/catalog_category.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../utils/catalog_assets.dart';
import '../widgets/catalog_states.dart';
import '../widgets/hero_product_card.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

/// Lista de productos de una categoría (§017 + integración §019).
/// La categoría se resuelve del CatalogCubit por `categorySlug` —
/// nombre del backend (dato), cover local por slug. El producto
/// `isFeatured` encabeza como hero ("El de la casa"); el resto son
/// ProductCards. Refresh silencioso al entrar.
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({required this.categorySlug, super.key});

  final String categorySlug;

  @override
  State<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CatalogCubit>().refresh();
  }

  CatalogCategory? _find(CatalogState state) {
    for (final c in state.categories) {
      if (c.slug == widget.categorySlug) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        final category = _find(state);
        if (category == null && state.categories.isEmpty) {
          if (state.status == CatalogStatus.error) {
            return Scaffold(
              body: CatalogErrorView(
                onRetry: () => context.read<CatalogCubit>().refresh(),
              ),
            );
          }
          return const Scaffold(body: CatalogLoadingView());
        }
        final products = category?.products ?? const [];
        final hero = products
            .where((p) => p.isFeatured && p.isAvailable)
            .firstOrNull;
        final items = products.where((p) => p != hero).toList();
        // … continúa abajo
      },
    );
  }
}
```

> **Nota para el implementador:** `firstOrNull` — si el proyecto ya usa
> `package:collection` impórtala; si no, escribe un mini-helper
> (`products.where((p) => p.isFeatured && p.isAvailable).isEmpty ? null
> : first`). Mantenerlo simple — un loop es suficiente.

**El cuerpo del `Scaffold`/`Stack` queda igual EXCEPTO:**

- `Text(_label(l10n), …)` → `Text(category?.name ?? '', …)` (dato del
  backend — la key l10n de categoría muere).
- `if (category == CatalogCategory.dogs) const HeroProductCard(item: depredadorItem)` →
  `if (hero != null) HeroProductCard(item: hero!, categorySlug: widget.categorySlug)`.
- El ghost "cupo fantasma" (`items.isEmpty`): `asset: category.coverAsset` →
  `asset: CatalogAssets.categoryCover(widget.categorySlug)` (se mantiene
  completo, solo cambia el asset).
- `for (final item in items) if (item != depredadorItem || category != CatalogCategory.dogs) ProductCard(item: item)` →
  `for (final item in items) ProductCard(item: item, categorySlug: widget.categorySlug)`.
- Scaffold envuelve el contenido como antes (mover el `return Scaffold(...)` dentro del BlocBuilder cuando category != null).

## 9. ProductDetailScreen (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/screens/product_detail_screen.dart`

Cambia a recibir `productSlug` + BlocBuilder; las selecciones quedan en
el State (sets de option.id — igual que hoy). Cambios:

**Antes (imports + firma):**

```dart
import '../data/catalog_mock.dart';
import '../widgets/customization_section.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.item, super.key});

  final CatalogItem item;
```

**Después:**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog_product.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../utils/catalog_assets.dart';
import '../utils/format_cop.dart';
import '../widgets/catalog_states.dart';
import '../widgets/customization_section.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.productSlug, super.key});

  final String productSlug;
```

**El State:** los 4 sets quedan (`_removed`, `_extras`, `_toppings`,
`_sauces` — ahora guardan `option.id` del backend). `_total` cambia:

```dart
  int get _total {
    var t = _item?.basePrice ?? 0;
    for (final o in _item?.additionalOptions ?? const []) {
      if (_extras.contains(o.id)) t += o.extraPrice;
    }
    return t;
  }
```

**initState** → `context.read<CatalogCubit>().refresh();`

**build:** BlocBuilder resuelve el producto por slug en TODAS las
categorías:

```dart
  CatalogProduct? _findProduct(CatalogState state) {
    for (final c in state.categories) {
      for (final p in c.products) {
        if (p.slug == widget.productSlug) return p;
      }
    }
    return null;
  }
```

- `categories.isEmpty && status==error` → `CatalogErrorView`.
- `categories.isEmpty && !error` → `CatalogLoadingView`.
- `product == null` tras success → vista inline "no disponible":
  icono `Icons.restaurant_outlined` + `l10n.productUnavailableTitle` +
  botón `FilledButton.tonalIcon(Icons.arrow_back, l10n.productUnavailableCta, onPressed: context.pop)` — mismo estilo de CatalogErrorView (reusar la composición).
- Con producto: el layout aprobado §018 queda idéntico excepto:

  - `final own = ingredientesOf(item)` → `final own = item.removableIngredients`
  - `final extras = adicionalesFor(item)` → `final extras = item.additionalOptions`
  - RemovableRow: `label: o.name`, `removed: _removed.contains(o.id)`,
    `enabled: o.isAvailable`, `onTap` igual. **Si `!o.isAvailable`**:
    `enabled: false` (gris, sin tap — la fila muestra el nombre, no se
    puede quitar porque ni siquiera está disponible).
  - OptionRow extras: `trailingLabel: o.isAvailable ? '+${formatCop(o.extraPrice)}' : l10n.catalogSoldOut`,
    `enabled: o.isAvailable`.
  - Toppings/salsas: `for (final o in toppingOptions) SelectChip(label: o.name, selected: _toppings.contains(o.id), enabled: o.isAvailable, onTap: () => _toggle(_toppings, o.id))` (igual sauces).
    Las secciones se renderizan solo si la lista no está vacía (`if (toppings.isNotEmpty)`).
  - Header card: `item.ingredients` → `item.ingredientsSummary`;
    `item.priceCop` → `item.basePrice`;
    `ProductImage(asset: item.imageAsset)` →
    `ProductImage(asset: CatalogAssets.productAsset(item.slug), imageUrl: item.imageUrl)`.
  - CTA: `item.isAvailable` → FilledButton con el toast provisional
    (sin cambio — carrito es otra propuesta); `!item.isAvailable` →
    `FilledButton(onPressed: null, child: Text(l10n.catalogSoldOut))`.

## 10. Cards (archivos existentes — actualización)

### `category_card.dart`

- `final CatalogCategory category` → misma firma pero el tipo ahora es la
  **entidad de dominio** (`../../domain/entities/catalog_category.dart`).
- `_label(l10n)` → `category.name` directo (eliminar el método y los
  imports de l10n si quedan solo para eso — `catalogProductsCount` y
  `comingSoon` se conservan).
- `catalogCountOf(category)` → `category.products.length`.
- `category.coverAsset` → `CatalogAssets.categoryCover(category.slug)`.
- `category.segment` → `category.slug` en el `context.push`.
- import `catalog_mock` → `../../domain/entities/catalog_category.dart` +
  `../utils/catalog_assets.dart`.

### `product_card.dart`

- `final CatalogItem item` → `final CatalogProduct item` (entidad) +
  **nuevo param** `final String categorySlug` (para el push).
- `_openDetail` →
  `context.push('/home/category/$categorySlug/product/${item.slug}')`.
- `item.priceCop` → `item.basePrice`; `item.tagline` igual (entity field);
  `item.imageAsset` → `CatalogAssets.productAsset(item.slug)` +
  `imageUrl: item.imageUrl`.
- **Agotado** (`!item.isAvailable`): el `InkWell` de la card y el del
  "+" reciben `onTap: null`; y en vez del círculo "+" se muestra un
  tag (SIN `Opacity` sobre card ni imagen — translucidez descartada
  por el usuario en revisión visual):
  ```dart
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      l10n.catalogSoldOut,
      style: text.labelSmall?.copyWith(
        color: colors.onErrorContainer,
        fontWeight: FontWeight.w800,
      ),
    ),
  )
  ```
  (en el mismo slot del SizedBox de 48dp — reemplaza el InkWell del "+").

### `hero_product_card.dart`

- `final CatalogItem item` → `final CatalogProduct item` + `final String
  categorySlug` (mismo param que ProductCard).
- `item.priceCop`/`item.imageAsset`/`item.id` → `item.basePrice` /
  `CatalogAssets.productAsset(item.slug)` + `imageUrl` / `item.slug`.
- Agotado: tag `catalogSoldOut` reemplazando el CTA + `onTap: null`
  — SIN `Opacity` (misma decisión que ProductCard).

## 11. ProductImage (archivo existente — actualización)

**Ruta:** `lib/features/home/presentation/widgets/product_image.dart`

**Antes:**

```dart
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.asset,
    required this.size,
    this.aspectRatio = 1,
    super.key,
  });

  final String asset;
  /// ...
  child: Image.asset(asset, fit: BoxFit.contain),
```

**Después:**

```dart
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.asset,
    required this.size,
    this.imageUrl,
    this.aspectRatio = 1,
    super.key,
  });

  /// Asset local por slug (fallback mientras no haya fotos remotas).
  final String asset;

  /// URL remota de product_images (hoy null — pendientes backend/006).
  final String? imageUrl;
  /// ... size/aspectRatio iguales ...
  child:
      imageUrl == null
          ? Image.asset(asset, fit: BoxFit.contain)
          : Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              // La remota falla o falta → asset local por slug.
              errorBuilder:
                  (_, __, ___) =>
                      Image.asset(asset, fit: BoxFit.contain),
            ),
```

## 12. CustomizationSection — soporte `enabled` (archivo existente)

**Ruta:** `lib/features/home/presentation/widgets/customization_section.dart`

- `OptionRow`: nuevo `final bool enabled` (default true) — cuando false:
  `InkWell(onTap: null)`, el contenido envuelto en
  `Opacity(opacity: 0.45)` y el trailing icon pasa a
  `Icons.cancel_rounded` en `colors.error` (X en círculo rojo —
  decisión del usuario). El `trailingLabel` lo decide el caller
  ("Agotado" en vez de "+$X").
- `RemovableRow`: nuevo `final bool enabled` (default true) — mismo
  tratamiento (sin tap + Opacity 0.45 + X roja sobre la fila).
- `SelectChip`: nuevo `final bool enabled` (default true) — false:
  `InkWell(onTap: null)` + `Opacity(0.45)` sobre el AnimatedContainer
  + `Icon(cancel_rounded, 14, error)` antes del nombre.

```dart
// Firma ejemplo (los tres iguales):
const OptionRow({
  required this.label,
  required this.selected,
  required this.onTap,
  this.trailingLabel,
  this.enabled = true,
  super.key,
});
```

## 13. l10n (archivo existente — actualización)

**Ruta:** `lib/l10n/app_es.arb`

**Agregar** (al final, con los `catalog*`/`detail*`):

```json
"catalogSoldOut": "Agotado",
"@catalogSoldOut": { "description": "Tag en cards/opciones sin disponibilidad" },
"catalogLoadErrorTitle": "No pudimos cargar la carta",
"@catalogLoadErrorTitle": { "description": "Título del estado de error del catálogo sin caché" },
"catalogLoadErrorSubtitle": "Revisa tu conexión e inténtalo de nuevo.",
"@catalogLoadErrorSubtitle": { "description": "Subtítulo del estado de error del catálogo" },
"catalogRetry": "Reintentar",
"@catalogRetry": { "description": "Botón de reintento del estado de error" },
"productUnavailableTitle": "Este producto ya no está en la carta",
"@productUnavailableTitle": { "description": "Detalle abierto con slug de producto eliminado o desconocido" },
"productUnavailableCta": "Volver al menú",
"@productUnavailableCta": { "description": "Botón de la vista producto-no-disponible" }
```

**Eliminar** (mueren con el enum — el nombre viene del backend):
`catalogCategoryDogs`, `catalogCategoryMore`, `catalogCategoryDrinks`,
`catalogCategoryCombos` (y sus `@` metadata si existen).

**Paso:** `flutter gen-l10n` (regenerar — NO editar el
`app_localizations*.dart` generado).

## 14. Eliminar el mock

`lib/features/home/presentation/data/catalog_mock.dart` — **borrar el
archivo completo** una vez ningún import quede (incluye el enum
`CatalogCategory`, `ingredientCatalog`, `toppingCatalog`,
`sauceCatalog`, `catalogMockItems`, `catalogItemById`, `depredadorItem`,
`formatCop` — ahora `utils/format_cop.dart`).

## 15. Tests

### `test/features/home/data/models/catalog_models_test.dart` (nuevo)

- `CatalogCategoryModel.fromJson` parsea el árbol completo con un JSON
  literal del contrato (categoría → producto → grupo → opción): tipos
  correctos, `num`→`int` en precios, `maxSelect: null`, `imageUrl:
  null`, `description`→`tagline`.
- Producto con `modifierGroups: []` → lista vacía sin explotar.

### `test/features/home/data/repositories/catalog_repository_impl_test.dart` (nuevo)

Mocks (mocktail): `ICatalogRemoteDataSource`, `INetworkInfo`.

- Con datos + conectividad → `Right(menu)`.
- `isConnected == false` → `Left(CatalogOfflineFailure)` y el datasource
  **nunca** se llama.
- `NoConnectionException` del datasource → `CatalogOfflineFailure`.
- Otra `NetworkException` (500) → `CatalogServerFailure`.
- Error no-NetworkException (cast roto) → `CatalogServerFailure` (red de
  seguridad).

### `test/features/home/presentation/cubit/catalog_cubit_test.dart` (nuevo)

`blocTest<CatalogCubit, CatalogState>` con `GetCatalogMenuUseCase`
mockeado (mocktail) + `ILoggerService` fake:

- `load()` desde initial → `[loading, success]` con el menú.
- `load()` falla sin datos → `[loading, error]` con failure.
- `load()` con éxito previo y sin forceRefresh → **no emite** (no-op).
- `refresh()` con datos → `[success]` con menú nuevo (sin pasar por
  loading).
- `refresh()` falla con datos → **no emite error** (queda success con
  los datos viejos + warn en logger).
- Dos `load()` concurrentes → el datasource se llama UNA vez (dedupe).

### `test/features/home/presentation/category_products_screen_test.dart` (reescritura)

- `MockCatalogCubit extends MockCubit<CatalogState> implements
  CatalogCubit` (bloc_test). Helper `pumpScreen(slug, state)` que
  envuelve `CategoryProductsScreen` en `BlocProvider.value` +
  `MaterialApp` + `GoRouter` mínimo con `product/:productSlug` (como el
  helper actual).
- Fixtures de dominio equivalentes al mock (mismo Cachorro/Depredador
  para no re-escribir aserciones): construir `CatalogCategory`/
  `CatalogProduct`/`ModifierGroup`/`ModifierOption` con los mismos
  nombres/precios.
- Mismas aserciones: hero presente, tagline ≤2 líneas, "+" navega a
  `/product/cachorro` (slug nuevo), ghost card cuando la categoría
  existe sin productos, loading/error cubiertos.

### `test/features/home/presentation/product_detail_screen_test.dart` (reescritura)

- Mismo patrón: fixture `CatalogProduct` con los grupos del modelo real
  (ingredients con defaults removibles + pan/salchicha no-removibles +
  extras; toppings; sauces).
- Aserciones: título, secciones (quitar solo removibles — pan/salchicha
  NO aparecen), extras con `+$`, chips, total dinámico al marcar extra,
  producto `isAvailable=false` → CTA deshabilitado con "Agotado",
  opción agotada → fila deshabilitada.

## 16. design-system.yaml + doc

- `Design/design-system.yaml`: bump menor + spec de los componentes
  nuevos (`sold_out_tag`, `catalog_states`) + nota de que las cards ya
  consumen datos reales (`imageUrl` con fallback por slug). Changelog.
- `pendientes/`: ningún pendiente nuevo de esta integración — el
  carrito (`detailAddToCart` sigue toast provisional) ya es scope del
  módulo orders (decisión tomada).

## Orden de aplicación

1. Entidades + failures + interfaz repo (domain).
2. Models + datasource + repository impl (data).
3. Cubit + state (presentation).
4. `setup_di` + `app_router` (wiring + provider).
5. Utils (`format_cop`, `catalog_assets`) + `catalog_states`.
6. Widgets (cards, product_image, customization_section).
7. Pantallas (home, category, detail).
8. `app_es.arb` + `flutter gen-l10n`.
9. Eliminar `catalog_mock.dart`.
10. Tests nuevos + reescritura de los existentes.
11. `dart format` en archivos tocados + `flutter analyze` + `flutter test`.
12. design-system.yaml + changelog.

## Verificación

- `flutter analyze` limpio, `flutter test` verde.
- **En vivo (emulador):** login → home muestra las 4 categorías reales
  del backend → Perros lista los 6 + hero Depredador → detalle con las
  4 secciones reales → marcar extra sube el total. Agotado: forzar
  `is_available=false` en BD para UN producto/UNA opción y ver tag
  "Agotado" sin atenuación / fila gris con X roja (verificación manual
  del flujo visual).
- Offline: modo avión → error view con reintento (primera carga) /
  datos persisten (refresh).
