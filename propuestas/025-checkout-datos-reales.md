# Propuesta: checkout con datos reales — `GET /addresses` + `GET /store/config` + `POST /addresses`

Ciclo 1 de integración (screen-first, fase 2). La presentación del
checkout ya está aprobada (§022-024); esta propuesta conecta los
tres datos que hoy mockea `CheckoutCubit` contra los endpoints reales
del backend (014 + 013):

- **`GET /addresses`** → `savedAddresses` reales (el backend ya
  ordena default-primero → el prefill "primera guardada" queda
  honesto sin cambiar la lógica).
- **`GET /store/config`** → `CheckoutStore` real (nombre, dirección
  del local, `deliveryFee`, `isOpen`, `minDeliveryOrder`).
- **`POST /addresses`** → "Guardar esta ubicación" deja de ser un
  checkbox que no hace nada: al confirmar con el checkbox marcado,
  la app guarda la dirección ANTES de confirmar el pedido (flujo de
  dos llamadas aprobado en el 015 — si el guardado falla, el pedido
  sigue y solo se avisa; la orden del ciclo 2 mandará `newAddress`
  como fallback).

**Fuera de alcance** (ciclos 2-4): `POST /orders` real, `GET /orders`,
cancelación real, Google Maps real (el pin sigue siendo el link mock
§022d — el payload ya lo soporta).

**Decisiones embebidas — encuestadas y aprobadas por el usuario:**

- **Store config viaja en este ciclo** — es un GET que la misma
  pantalla ya muestra (fee, "Lo recoges en…"); conectarlo junto a
  addresses deja el checkout 100% honesto.
- **Falla de `GET /addresses`** → el bloque de domicilio cae a
  "Nueva ubicación" como única opción + aviso inline con retry
  (NO bloquea el pickup — quien recoge en el local no necesita
  dirección).
- **Falla del `POST /addresses`** al confirmar → el pedido continúa
  (la dirección va como `newAddress` en la orden) + toast "no se
  pudo guardar la ubicación" — el guardado es auxiliar, nunca debe
  abortar una compra.
- **Local cerrado** (`isOpen: false`) → el CTA de confirmar se
  deshabilita con aviso inline "El local está cerrado" — el backend
  ya rechaza con 409, pero es mejor no dejar llegar.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/checkout/domain/failures/checkout_failure.dart` | **nuevo** — sealed Offline/Server |
| `lib/features/checkout/domain/repositories/i_checkout_repository.dart` | **nuevo** — los 3 métodos |
| `lib/features/checkout/domain/use_cases/load_checkout_data_use_case.dart` | **nuevo** — fans out los 2 GET en paralelo |
| `lib/features/checkout/domain/use_cases/save_address_use_case.dart` | **nuevo** |
| `lib/features/checkout/domain/entities/checkout_store.dart` | + `isOpen`, `minDeliveryOrder`, `logoUrl` |
| `lib/features/checkout/data/models/saved_address_model.dart` | **nuevo** — fromJson (`type` string→enum) |
| `lib/features/checkout/data/models/checkout_store_model.dart` | **nuevo** — fromJson (nullables honestos) |
| `lib/features/checkout/data/datasources/interfaces/i_checkout_remote_datasource.dart` | **nuevo** |
| `lib/features/checkout/data/datasources/implementations/checkout_remote_datasource_impl.dart` | **nuevo** |
| `lib/features/checkout/data/repositories/checkout_repository_impl.dart` | **nuevo** |
| `lib/features/checkout/presentation/cubit/checkout_state.dart` | + flags loading/error/saveFailed |
| `lib/features/checkout/presentation/cubit/checkout_cubit.dart` | sin seeds mock — `loadCheckoutData()`, confirm con save real, guardia de cerrado |
| `lib/features/checkout/presentation/widgets/delivery_address_block.dart` | loading, empty-state, error+retry inline |
| `lib/features/checkout/presentation/screens/checkout_screen.dart` | aviso de cerrado + CTA deshabilitado |
| `lib/core/di/setup_di.dart` | wiring de las piezas nuevas |
| `lib/l10n/app_es.arb` + generados | keys de error/empty/retry/cerrado |
| specs de cubit/repo/use-case | actualizar + nuevos |

## 1. Dominio

**`checkout_failure.dart`** (nuevo) — mismo patrón de
`CatalogFailure`:

```dart
sealed class CheckoutFailure extends Equatable {
  const CheckoutFailure();
  @override
  List<Object?> get props => [];
}
final class CheckoutOfflineFailure extends CheckoutFailure {
  const CheckoutOfflineFailure();
}
final class CheckoutServerFailure extends CheckoutFailure {
  const CheckoutServerFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
```

**`checkout_store.dart`** — agregar campos reales del endpoint:

```dart
class CheckoutStore extends Equatable {
  const CheckoutStore({
    required this.name,
    required this.address,
    required this.deliveryFee,
    this.isOpen = true,
    this.minDeliveryOrder,
    this.logoUrl,
  });
  // ...existentes +
  /// Derivado del horario del negocio (backend 013) — si false, el
  /// checkout bloquea el confirm (el backend rechaza con 409).
  final bool isOpen;
  /// Mínimo de domicilio en COP; null = sin mínimo (decisión §022).
  final int? minDeliveryOrder;
  final String? logoUrl;
  // props: + isOpen, minDeliveryOrder, logoUrl
}
```

**`i_checkout_repository.dart`** (nuevo):

```dart
abstract class ICheckoutRepository {
  /// Las mías — el backend ordena default-primero (§014).
  Future<Either<CheckoutFailure, List<SavedAddress>>> getSavedAddresses();

  /// Config del negocio — nombre, dirección del local, fee, isOpen.
  Future<Either<CheckoutFailure, CheckoutStore>> getStoreConfig();

  /// "Guardar esta ubicación" — POST /addresses con el label final
  /// (la app traduce home→'Casa', work→'Trabajo', other→texto libre;
  /// el backend exige label siempre, decisión §014).
  Future<Either<CheckoutFailure, SavedAddress>> saveAddress({
    required String label,
    required String landmark,
    String? neighborhood,
    required SavedAddressType type,
  });
}
```

**`load_checkout_data_use_case.dart`** (nuevo) — los dos GET son
independientes: un fallo de uno no debe tumbar al otro (la pantalla
degrada por bloque):

```dart
/// Resultado de la carga inicial del checkout — cada pierna lleva su
/// propio Either para que la pantalla degrade por bloque (direcciones
/// vs. datos del local), no en conjunto.
class CheckoutDataResult {
  const CheckoutDataResult({required this.addresses, required this.store});
  final Either<CheckoutFailure, List<SavedAddress>> addresses;
  final Either<CheckoutFailure, CheckoutStore> store;
}

class LoadCheckoutDataUseCase {
  const LoadCheckoutDataUseCase(this._repo);
  final ICheckoutRepository _repo;

  Future<CheckoutDataResult> call() async {
    final results = await Future.wait([
      _repo.getSavedAddresses(),
      _repo.getStoreConfig(),
    ]);
    return CheckoutDataResult(
      addresses: results[0] as Either<CheckoutFailure, List<SavedAddress>>,
      store: results[1] as Either<CheckoutFailure, CheckoutStore>,
    );
  }
}
```

**`save_address_use_case.dart`** (nuevo) — delegación fina:

```dart
class SaveAddressUseCase {
  const SaveAddressUseCase(this._repo);
  final ICheckoutRepository _repo;

  Future<Either<CheckoutFailure, SavedAddress>> call({
    required String label,
    required String landmark,
    String? neighborhood,
    required SavedAddressType type,
  }) => _repo.saveAddress(
    label: label,
    landmark: landmark,
    neighborhood: neighborhood,
    type: type,
  );
}
```

## 2. Data

**`saved_address_model.dart`** (nuevo) — extiende la entidad:

```dart
class SavedAddressModel extends SavedAddress {
  const SavedAddressModel({
    required super.id,
    required super.label,
    required super.landmark,
    super.neighborhood,
    super.type,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id'] as String,
      label: json['label'] as String,
      landmark: json['landmark'] as String,
      neighborhood: (json['neighborhood'] as String?) ?? '',
      type: _typeFromString(json['type'] as String?),
    );
  }

  static SavedAddressType _typeFromString(String? raw) =>
      switch (raw) {
        'home' => SavedAddressType.home,
        'work' => SavedAddressType.work,
        _ => SavedAddressType.other,
      };
}
```

**`checkout_store_model.dart`** (nuevo) — los nullables del contrato
viajan honestos (`address`/`logoUrl` pueden ser null):

```dart
class CheckoutStoreModel extends CheckoutStore {
  const CheckoutStoreModel({
    required super.name,
    required super.address,
    required super.deliveryFee,
    required super.isOpen,
    super.minDeliveryOrder,
    super.logoUrl,
  });

  factory CheckoutStoreModel.fromJson(Map<String, dynamic> json) {
    return CheckoutStoreModel(
      name: json['name'] as String,
      address: (json['address'] as String?) ?? '',
      deliveryFee: (json['deliveryFee'] as num).toInt(),
      isOpen: json['isOpen'] as bool,
      minDeliveryOrder: (json['minDeliveryOrder'] as num?)?.toInt(),
      logoUrl: json['logoUrl'] as String?,
    );
  }
}
```

**`i_checkout_remote_datasource.dart`** + impl (nuevo) — solo llama
y parsea, mismo SRP del de catálogo:

```dart
abstract class ICheckoutRemoteDataSource {
  Future<List<SavedAddressModel>> fetchAddresses();
  Future<CheckoutStoreModel> fetchStoreConfig();
  Future<SavedAddressModel> createAddress(Map<String, dynamic> body);
}
```

```dart
class CheckoutRemoteDataSourceImpl implements ICheckoutRemoteDataSource {
  const CheckoutRemoteDataSourceImpl({required this._networkService});
  final INetworkService _networkService;

  @override
  Future<List<SavedAddressModel>> fetchAddresses() async {
    final response = await _networkService.get('/addresses');
    return (response as List<dynamic>)
        .map((a) => SavedAddressModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CheckoutStoreModel> fetchStoreConfig() async {
    final response = await _networkService.get('/store/config');
    return CheckoutStoreModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<SavedAddressModel> createAddress(Map<String, dynamic> body) async {
    final response = await _networkService.post('/addresses', body: body);
    return SavedAddressModel.fromJson(response as Map<String, dynamic>);
  }
}
```

**`checkout_repository_impl.dart`** (nuevo) — mismo traductor que
`CatalogRepositoryImpl`: networkInfo → NetworkException →
OfflineFailure/ServerFailure, y el catch de respaldo para bodies
malformados. `saveAddress` arma el body con `type.name` (el enum
del backend es exactamente `home|work|other`).

## 3. Estado y cubit

**`checkout_state.dart`** — campos nuevos:

```dart
/// Carga inicial de direcciones + store en vuelo — los bloques
/// muestran placeholder/skeleton, no datos mock.
final bool dataLoading;
/// GET /addresses falló → el bloque cae a "Nueva ubicación" como
/// única opción + aviso con retry (el pickup nunca se bloquea).
final bool addressesFailed;
/// GET /store/config falló → las líneas del local quedan en "—" +
/// aviso con retry.
final bool storeFailed;
/// POST /addresses falló al confirmar con "guardar" — el pedido
/// continuó igual; la UI lo avisa con toast al éxito.
final bool addressSaveFailed;
/// El guardado de la ubicación corrió dentro del confirm.
final SavedAddress? justSavedAddress;
```

Defaults: `dataLoading: true`, resto false/null. `kCheckoutMockAddresses`
y `kCheckoutMockStore` se **eliminan** (el initial es
`savedAddresses: []`, `store:` placeholder vacío con `isOpen: true`).

**`checkout_cubit.dart`** — cambios:

- Constructor: nuevo dep `LoadCheckoutDataUseCase` +
  `SaveAddressUseCase`; initial state con listas vacías y
  `dataLoading: true`. El prefill `addressId` se resuelve al cargar
  (no en el constructor — aún no hay direcciones).
- **`loadCheckoutData()`** — emite `dataLoading: true`, llama el
  use-case, y por pierna:
  - addresses ok → `savedAddresses`, `addressId` = `first.id` si no
    vacío, `kCheckoutNewAddressId` si vacía; `addressesFailed:false`.
  - addresses fail → `addressesFailed: true`, `savedAddresses: []`,
    `addressId: kCheckoutNewAddressId` (fallback — la única opción).
  - store ok → `store` real; store fail → `storeFailed: true` +
    store placeholder con `isOpen: false` (cerrado por defecto =
    seguro).
  - `dataLoading: false` al final.
- **`confirm()`** — tras la validación inline y ANTES del delay mock:
  ```dart
  if (_shouldSaveNewAddress) {
    emit(state.copyWith(confirmInProgress: true));
    final result = await saveAddressUseCase(
      label: _resolvedNewAddressLabel,   // home→'Casa' l10n, work→'Trabajo', other→newAddressLabel
      landmark: state.newLandmark.trim(),
      neighborhood: state.newNeighborhood.trim().isEmpty
          ? null : state.newNeighborhood.trim(),
      type: state.newAddressType,
    );
    result.fold(
      (f) => emit(state.copyWith(addressSaveFailed: true)),
      (saved) => emit(state.copyWith(
        savedAddresses: [...state.savedAddresses, saved],
        justSavedAddress: saved,
      )),
    );
    if (isClosed) return;
  }
  ```
  `_shouldSaveNewAddress` = `orderType==delivery &&
  addressId==kCheckoutNewAddressId && saveNewAddress &&
  hasValidDeliveryTarget`. Luego el delay mock + `orderConfirmed`
  (el POST /orders real llega en ciclo 2 y usará
  `justSavedAddress?.id ?? newAddress` como destino).
- **Guardia de cerrado**: `if (!state.store.isOpen) return;` al
  inicio de `confirm()` (la UI ya lo deshabilita — defensa).
- `pickup`/`delivery` toggles y demás métodos: sin cambio salvo que
  `selectAddress`/`toggleNewAddress` no-op mientras `dataLoading`.

## 4. Pantalla

**`delivery_address_block.dart`**:
- `dataLoading` → placeholder de carga en la sección (skeleton o
  spinner chico — el CTA de confirmar también espera).
- `addressesFailed` → fila de aviso "No pudimos cargar tus
  ubicaciones" + botón `Reintentar` (llama `loadCheckoutData()`).
- `savedAddresses` vacío (cliente nuevo) → solo la fila "Nueva
  ubicación" — sin texto extra, la UI ya se explica sola.
- El bloque de dirección guardada usa `addr.detail` igual que hoy.

**`checkout_screen.dart`**:
- `storeFailed` → la línea "Lo recoges en …" cae a "—" + aviso de
  retry cerca del resumen.
- `!store.isOpen` → banner inline "El local está cerrado ahora" y
  CTA deshabilitado (el backend respondería 409 — mejor ni llegar).
- `addressSaveFailed` + `orderConfirmed` → `AppToast.info` "Pedido
  confirmado — no pudimos guardar la ubicación" junto al diálogo.

**l10n** (`app_es.arb`): `checkoutAddressesError`,
`checkoutRetry`, `checkoutStoreError`, `checkoutStoreClosed`,
`checkoutAddressSaveFailed`, `checkoutAddressEmpty` (si se usa).

## 5. DI

`setup_di.dart` — registrar:
`ICheckoutRemoteDataSource` (lazySingleton) → `ICheckoutRepository`
(lazySingleton) → `LoadCheckoutDataUseCase` + `SaveAddressUseCase`
(lazySingleton) → `CheckoutCubit` (factory — mismos deps + los dos
use-cases nuevos). El `..loadCheckoutData()` va en el `create:` del
`BlocProvider` del router (misma convención del resto).

## 6. Tests

- `load_checkout_data_use_case_test.dart` — ambos GET ok; una pierna
  falla no tumba la otra (Either independientes).
- `save_address_use_case_test.dart` — delegación.
- `checkout_repository_impl_test.dart` — Either mapping offline/
  server/malformado (mismo set de casos que el de catálogo).
- `checkout_cubit_test.dart` — actualizar (constructor nuevo +
  mocks de use-cases):
  - load ok → savedAddresses reales + addressId=primera + store real.
  - load con lista vacía → addressId='new' + form expandido.
  - load addresses fail → addressesFailed + fallback 'new'.
  - confirm con saveNewAddress ok → savedAddresses gana la nueva.
  - confirm con save fail → orderConfirmed igual + addressSaveFailed.
  - `store.isOpen=false` → confirm() no avanza.
  - los tests de validación existentes (teléfono, dirección, pago)
    siguen pasando sobre el estado cargado.
- Widget test del checkout — actualizar con cubit mockeado/estado
  cargado; agregar caso del banner de cerrado.

## Orden de aplicación

1. Failure + repository interface + entidad store actualizada
2. Models + datasource + repository impl
3. Use-cases + DI wiring
4. State + cubit (load + confirm-save + guardia cerrado)
5. Widgets (loading/empty/error/cerrado) + l10n
6. Tests
7. `flutter analyze` + `flutter test` verdes → emulador para
   aprobación visual (no commit hasta el OK)
