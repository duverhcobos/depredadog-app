# Propuesta: Perfil — presentación (identidad + código + direcciones + logout)

Pantalla del tab **Perfil** (hoy `ModulePlaceholderScreen`) en fase de
presentación: datos **mock** en los cubits, sin domain/data real todavía
— mismo patrón que §023 (orders) y §020/§022 (cart/checkout). El usuario
la señaló como el gap del rol cliente tras cerrar admin backend (§019).

Cubrimos **2 pantallas**: la principal del tab y la sub-pantalla "Mis
direcciones" (hija de la rama profile — conserva shell+nav igual que
`/orders/:id`). Así el usuario aprueba la vista completa del feature de
una vez y después integramos endpoint por endpoint.

## Qué contiene (decisiones del usuario — encuesta respondida)

1. **Tarjeta de identidad**: avatar con iniciales + nombre completo +
   email + celular (fila oculta si `phone` es null). La edición llega
   con la ampliación §030.1 (fila "Mis datos" → form propio).
2. **Tarjeta de código de referido**: "Tu código" + botón copiar
   (`Clipboard` nativo — sin `share_plus`) + `AppToast` "Código copiado".
   Ya funciona en fase 1 con el mock.
3. **Fila "Mis direcciones"** → empuja `/profile/addresses` — gestión
   **completa** (decisión usuario): lista con badge "Predeterminada",
   marcar otra como default (PATCH `{isDefault:true}` — el backend
   hace la exclusividad), eliminar con diálogo (DELETE), y
   **crear/editar** en una tercera pantalla `/profile/addresses/form`
   (misma estructura de campos que `new_address_form` del checkout:
   chips tipo Casa/Trabajo/Otro, landmark requerido, neighborhood
   opcional, label solo visible para "Otro").
4. **Fila "Soporte"** (decisión usuario): `Icons.support_agent_rounded`
   → `AlertDialog` con el WhatsApp del local + botón copiar número
   (mismo patrón Clipboard+toast del referido). El número es const
   `kSupportPhone` placeholder en fase 1 — la integración lo toma del
   store config cuando `store_settings` gane `support_phone`, o se
   deja pendiente explícito.
5. **"Cerrar sesión"**: fila destructiva → diálogo de confirmación real
   (estilo `order_cancel_dialog`); la acción es mock en fase 1. En
   integración (decisión usuario): `POST /auth/logout` **best-effort**
   — aunque falle (sin red/5xx) se borran tokens locales +
   `markLoggedOut` + `context.go('/login')`; "cerrar sesión" siempre
   funciona.
6. **Datos**: `ProfileCubit` con `User` de auth (la entidad ya existe —
   se reutiliza, no se duplica) + `referralCode` mock en el state.
   `ProfileAddressesCubit` con lista mock de `SavedAddress` — la
   entidad de checkout **se extiende en esta propuesta** con
   `isDefault` (el badge y el PATCH lo necesitan; el recurso ya lo
   tiene) y `copyWith` — aditivo, no rompe el contrato del checkout.
7. **Patrones visuales**: reutiliza `SignatureStrip`, título
   `scrolling_title` (`widthFactor 0.602`, headlineSmall primary w800),
   `AppToast`, diálogo estilo `order_cancel_dialog`, `SelectChip` de
   checkout para el tipo de dirección.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/profile/presentation/screens/profile_screen.dart` | **nuevo** — tab real |
| `lib/features/profile/presentation/screens/profile_addresses_screen.dart` | **nuevo** — gestión completa |
| `lib/features/profile/presentation/screens/address_form_screen.dart` | **nuevo** — crear/editar compartida |
| `lib/features/profile/presentation/cubit/profile_cubit.dart` | **nuevo** — mock user/referral/count + logout stub |
| `lib/features/profile/presentation/cubit/profile_state.dart` | **nuevo** |
| `lib/features/profile/presentation/cubit/profile_addresses_cubit.dart` | **nuevo** — mock list + markDefault + delete + upsert |
| `lib/features/profile/presentation/cubit/profile_addresses_state.dart` | **nuevo** |
| `lib/features/profile/presentation/widgets/profile_identity_card.dart` | **nuevo** |
| `lib/features/profile/presentation/widgets/profile_referral_card.dart` | **nuevo** |
| `lib/features/profile/presentation/widgets/profile_menu_row.dart` | **nuevo** — fila ícono+label+subtítulo+chevron |
| `lib/features/profile/presentation/widgets/profile_address_tile.dart` | **nuevo** |
| `lib/features/profile/presentation/widgets/profile_support_dialog.dart` | **nuevo** — WhatsApp + copiar |
| `lib/features/profile/presentation/widgets/logout_confirm_dialog.dart` | **nuevo** — estilo order_cancel_dialog |
| `lib/features/checkout/domain/entities/saved_address.dart` | **+`isDefault` + `copyWith`** — aditivo (el badge y PATCH {isDefault} lo necesitan) |
| `lib/core/routes/app_router.dart` | branch profile: placeholder → `ProfileScreen` + hijas `addresses` y `addresses/form` |
| `lib/core/routes/auth_guard.dart` | `profileAddressesRoute` + `profileAddressFormRoute` |
| `lib/l10n/app_es.arb` + `app_en.arb` | ~30 claves nuevas |
| `test/features/profile/**` | **nuevos** — cubits + widget tests de las 3 pantallas |

Registro DI: los cubits son **factory por entrada** (`locator` al
construir la ruta — igual que OrdersCubit en §027), no singleton del
shell: el perfil cambia poco pero se refresca en cada visita.

---

## 1. Entidades — una reutilizada, una extendida

```dart
// lib/features/auth/domain/entities/user.dart — YA EXISTE, sin tocar:
// id, email, firstName, secondName?, firstLastName, secondLastName?,
// phone?, role, status. `referralCode` se sumará en la fase de
// integración (el propio docstring lo prevé: "se suma cuando una
// pantalla real los necesite") — fase 1 lo mockea el state.

// lib/features/checkout/domain/entities/saved_address.dart — EXTENDIDA:
// el contrato actual es reducido para el checkout (sin isDefault ni
// copyWith — el checkout solo necesita "la primera"). Profile necesita
// el flag para el badge y el PATCH {isDefault:true}. Cambio aditivo:

class SavedAddress extends Equatable {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.landmark,
    this.neighborhood = '',
    this.type = SavedAddressType.other,
    this.isDefault = false, // NUEVO — el recurso ya lo tiene; default false
  });

  // ... campos existentes intactos ...
  /// Marca del backend — exclusiva por usuario (una sola por índice
  /// parcial). El checkout no la usa; profile la muestra como badge.
  final bool isDefault;

  SavedAddress copyWith({
    String? id,
    String? label,
    String? landmark,
    String? neighborhood,
    SavedAddressType? type,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      landmark: landmark ?? this.landmark,
      neighborhood: neighborhood ?? this.neighborhood,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  // props += isDefault
}
// Riesgo cero para checkout: campo con default + props extendido;
// sus constructores existentes compilan igual.
```

## 2. `profile_state.dart` (archivo nuevo)

**Ruta:** `lib/features/profile/presentation/cubit/profile_state.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user.dart';

/// Estado del tab Perfil (§030, solo presentación): usuario mock +
/// código de referido + contador de direcciones para el subtítulo del
/// menú. En integración `user` viene de GET /auth/me (fresco al abrir
/// el tab, con AuthSession.currentUser como primer render) y
/// `addressesCount` de GET /addresses.
class ProfileState extends Equatable {
  const ProfileState({
    required this.user,
    this.referralCode,
    this.addressesCount = 0,
    this.loggingOut = false,
  });

  /// Usuario autenticado — null solo antes del primer render (fase 1
  /// siempre tiene el mock).
  final User? user;

  /// Código de referido propio — mock en fase 1; en fase 2 lo trae
  /// GET /auth/me (la entidad User gana el campo en ese ciclo).
  final String? referralCode;

  /// Total de direcciones guardadas — subtítulo de la fila del menú.
  final int addressesCount;

  /// Spinner del diálogo de logout — fase 1 no lo usa (acción mock).
  final bool loggingOut;

  ProfileState copyWith({
    User? user,
    String? referralCode,
    int? addressesCount,
    bool? loggingOut,
  }) {
    return ProfileState(
      user: user ?? this.user,
      referralCode: referralCode ?? this.referralCode,
      addressesCount: addressesCount ?? this.addressesCount,
      loggingOut: loggingOut ?? this.loggingOut,
    );
  }

  @override
  List<Object?> get props =>
      [user, referralCode, addressesCount, loggingOut];
}
```

## 3. `profile_cubit.dart` (archivo nuevo — mock)

**Ruta:** `lib/features/profile/presentation/cubit/profile_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user.dart';
import 'profile_state.dart';

/// Datos mock del tab Perfil (§023 pattern — contrato real, datos
/// ficticios). En integración: `load()` = GET /auth/me + conteo de
/// direcciones; `logout()` = POST /auth/logout + limpieza local.
final kMockProfileUser = User(
  id: 'mock-u1',
  email: 'ana@test.com',
  firstName: 'Ana',
  firstLastName: 'López',
  phone: '3001234567',
  role: 'customer',
  status: 'active',
);

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit()
      : super(const ProfileState(
          user: kMockProfileUser,
          referralCode: 'XK2P9QRD',
          addressesCount: 3,
        ));

  /// Fase 1: la acción real (POST /auth/logout + limpieza) es del
  /// ciclo de integración — el diálogo ya es real, esto solo marca.
  Future<void> logout() async {}
}
```

## 4. `profile_addresses_state.dart` (archivo nuevo)

**Ruta:** `lib/features/profile/presentation/cubit/profile_addresses_state.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../../checkout/domain/entities/saved_address.dart';

/// Lista de direcciones guardadas (§030 presentación): mutaciones
/// optimistas locales (marcar default / eliminar) — la integración
/// hará PATCH/DELETE real con rollback al fallar.
class ProfileAddressesState extends Equatable {
  const ProfileAddressesState({required this.addresses});

  final List<SavedAddress> addresses;

  /// La predeterminada — una sola por contrato del backend.
  SavedAddress? get defaultAddress {
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return null;
  }

  ProfileAddressesState copyWith({List<SavedAddress>? addresses}) {
    return ProfileAddressesState(
      addresses: addresses ?? this.addresses,
    );
  }

  @override
  List<Object?> get props => [addresses];
}
```

## 5. `profile_addresses_cubit.dart` (archivo nuevo — mock)

**Ruta:** `lib/features/profile/presentation/cubit/profile_addresses_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../checkout/domain/entities/saved_address.dart';
import 'profile_addresses_state.dart';

/// Mocks de direcciones (§030) — tres filas: default casa, trabajo,
/// otra. En integración: GET /addresses (default-primero lo ordena el
/// backend), POST crear, PATCH :id (editar / {isDefault:true}), DELETE.
final kMockAddresses = <SavedAddress>[
  const SavedAddress(
    id: 'a1',
    label: 'Casa',
    landmark: 'Casa blanca reja negra',
    neighborhood: 'Barrio Centro',
    type: SavedAddressType.home,
    isDefault: true,
  ),
  const SavedAddress(
    id: 'a2',
    label: 'Trabajo',
    landmark: 'Oficina 201, edificio azul',
    neighborhood: 'Pueblo Nuevo',
    type: SavedAddressType.work,
  ),
  const SavedAddress(
    id: 'a3',
    label: 'Mamá',
    landmark: 'Frente al parque',
    type: SavedAddressType.other,
  ),
];

class ProfileAddressesCubit extends Cubit<ProfileAddressesState> {
  ProfileAddressesCubit()
      : super(const ProfileAddressesState(addresses: kMockAddresses));

  /// Fase 1: mutación optimista local — exclusividad de default como
  /// la hace el backend (una sola predeterminada).
  void markDefault(String id) {
    emit(state.copyWith(
      addresses: [
        for (final a in state.addresses) a.copyWith(isDefault: a.id == id),
      ],
    ));
  }

  /// Fase 1: borrado local. En integración: DELETE con rollback si el
  /// servidor rechaza + herencia de default que resuelve el backend
  /// (si borras la default, otra la hereda — re-fetch honesto).
  void delete(String id) {
    emit(state.copyWith(
      addresses: [
        for (final a in state.addresses)
          if (a.id != id) a,
      ],
    ));
  }

  /// Fase 1: upsert del form (crear → id mock, editar → reemplaza).
  /// En integración: POST para nueva (el backend la asigna default si
  /// es la primera) / PATCH :id para editar — ambos con la lista
  /// reordenada default-primero que devuelve el backend.
  void upsert(SavedAddress address) {
    final existing = state.addresses.any((a) => a.id == address.id);
    emit(state.copyWith(
      addresses: [
        for (final a in state.addresses)
          if (a.id == address.id) address else a,
        if (!existing) address,
      ],
    ));
  }
}
```

> NOTA implementador: verificar la firma real de `SavedAddress`
> (`copyWith`, campos exactos) en `checkout/domain/entities/` antes de
> escribir el mock — si `copyWith` no existe, construir instancias
> nuevas en `markDefault` con los campos copiados.

## 6. `profile_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/profile/presentation/screens/profile_screen.dart`

Estructura — `SignatureStrip` + `ListView` (título scrolling como
primer hijo) + `BlocBuilder<ProfileCubit, ProfileState>`:

```dart
Scaffold(
  body: Stack(
    children: [
      const SignatureStrip(fraction: kSignatureStripFraction),
      BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final user = state.user;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _ProfileTitle(), // scrolling_title "Perfil"
              if (user != null)
                ProfileIdentityCard(user: user),
              if (state.referralCode != null)
                ProfileReferralCard(code: state.referralCode!),
              const SizedBox(height: 8),
              ProfileMenuRow(
                icon: Icons.location_on_outlined,
                title: l10n.profileAddressesRow,
                subtitle: l10n.profileAddressesCount(state.addressesCount),
                onTap: () => context.push(AuthGuard.profileAddressesRoute),
              ),
              ProfileMenuRow(
                icon: Icons.support_agent_rounded,
                title: l10n.profileSupportRow,
                onTap: () => showProfileSupportDialog(context),
              ),
              const SizedBox(height: 24),
              // Fila destructiva — texto error, sin icono de salida aún
              // (lo decide la crítica de diseño).
              ProfileMenuRow(
                icon: Icons.logout_rounded,
                title: l10n.profileLogoutRow,
                destructive: true,
                onTap: () => showLogoutConfirmDialog(context),
              ),
            ],
          );
        },
      ),
    ],
  ),
)
```

`ProfileIdentityCard` — `Card` (surfaceContainer, radius 16, margin
14/8/14/8) con `CircleAvatar` (iniciales de `firstName`+`firstLastName`,
bg primaryContainer, fg onPrimaryContainer, radius 26) + `Column`:
nombre completo `titleMedium` w700 (firstName + secondName? +
firstLastName + secondLastName?, uniendo no-null con espacio), email
`bodyMedium` onSurfaceVariant, celular `bodyMedium` onSurfaceVariant
**solo si `phone != null`** (ícono `Icons.phone_outlined` 16px).

`ProfileReferralCard` — `Card` hermana: `bodySmall` label "Tu código
de referido", `Row`: código `titleMedium` `FontFeatures` mono o
`letterSpacing: 2` w800 + `IconButton` `Icons.copy_rounded`
`tooltip: l10n.profileCopyCode` →
`Clipboard.setData(ClipboardData(text: code))` +
`AppToast.show(context, l10n.profileCopiedToast)` (ícono check).

`ProfileMenuRow` — `ListTile`-like reutilizable: `InkWell` en `Card`,
`leading` ícono en contenedor 40px primaryContainer/onPrimaryContainer,
`title` `titleSmall` w600 (`destructive` → color error), `subtitle`
opcional `bodySmall`, `trailing` chevron (`destructive` → sin chevron).
`Semantics(button: true, label: title)`.

`ProfileSupportDialog` — `AlertDialog` (radio 20 como
`order_cancel_dialog`): título `supportDialogTitle`, cuerpo
`supportDialogBody` + `Row` con el número `kSupportPhone` (titleMedium
letterSpacing 1) e `IconButton` copiar (Clipboard + toast
`profileCopiedToast`), acción `TextButton` "Cerrar". La const:

```dart
/// WhatsApp del local — PLACEHOLDER de presentación. La integración
/// lo toma de store_settings.support_phone cuando exista (pendiente
/// declarado); mientras tanto el diálogo lo muestra igual.
const String kSupportPhone = '+57 300 000 0000';
```

## 7. `profile_addresses_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/profile/presentation/screens/profile_addresses_screen.dart`

Misma carcasa (strip + ListView + `_AddressesTitle` scrolling
"Mis direcciones") + `BlocBuilder<ProfileAddressesCubit,…>`:

- `addresses.isEmpty` → estado vacío: ícono `location_off_outlined`
  48px onSurfaceVariant + `addressesEmpty` titleSmall +
  `addressesEmptyHint` bodySmall (centrados, misma familia que el
  vacío del carrito).
- Lista → `ProfileAddressTile` por fila: `Card` con `leading` ícono
  por tipo (`home`→`home_outlined`, `work`→`work_outline`,
  `other`→`place_outlined`), `title` = label `titleSmall` w600 +
  `default` badge (`Chip` mini "Predeterminada", primaryContainer —
  solo `isDefault`), `subtitle` landmark + ` · ` + neighborhood si
  existe, `onTap` → edición (`context.push(profileAddressFormRoute,
  extra: address)`), `trailing` `PopupMenuButton`:
  - "Marcar predeterminada" (`Icons.star_outline`) — **deshabilitada**
    si ya es default (Item enabled:false, gris).
  - "Eliminar" (`Icons.delete_outline`, texto error) → diálogo
    confirmación (`AlertDialog` patrón `order_cancel_dialog`: título
    `addressDeleteConfirmTitle`, cuerpo `addressDeleteConfirmBody`,
    cancelar / confirmar rojo) → `cubit.delete(id)`.
- CTA al pie: `FilledButton.tonalIcon` `Icons.add_location_alt_outlined`
  `addressesNewCta` → `context.push(profileAddressNewRoute)` — ancho
  completo, margen 14 (misma familia que "Agregar" del carrito).

## 7b. `address_form_screen.dart` (archivo nuevo)

**Ruta:** `lib/features/profile/presentation/screens/address_form_screen.dart`

Pantalla **compartida crear/editar** — `AddressFormScreen({this.editing})`
con `editing: SavedAddress?` (null → crear). Carcasa strip + ListView +
`_FormTitle` scrolling (`addressesNewTitle` / `addressesEditTitle` según
`editing`), y el mismo esquema de campos que `new_address_form` del
checkout:

- `Row` de 3 `SelectChip` (reusa el widget del checkout si es público;
  si está anidado en `new_address_form`, se extrae a
  `checkout/presentation/widgets/` o se replica el patrón — verificar
  en implementación): Casa/Trabajo/Otro — `type` local del form.
- `CustomTextField` landmark — requerido, `addressesLandmarkLabel` +
  hint; error inline `addressesLandmarkRequired` si se confirma vacío.
- `CustomTextField` neighborhood — opcional, `addressesNeighborhoodLabel`.
- `CustomTextField` label — **visible solo si `type == other`**
  (AnimatedSwitcher como el del checkout), `addressesLabelLabel`;
  home/work generan el label solos ("Casa"/"Trabajo" — la traducción
  la hace la capa de integración, fase 1 arma el SavedAddress mock con
  el texto del chip).
- `FilledButton` ancho completo `addressFormSave` — valida landmark
  (y label si other), arma el `SavedAddress` (editar: `editing.copyWith`;
  crear: `id: 'mock-${DateTime.now().millisecondsSinceEpoch}'`,
  `isDefault: state.addresses.isEmpty`) →
  `context.read<ProfileAddressesCubit>().upsert(a)` +
  `context.pop()`.

Estado local del form (`StatefulWidget` con controllers + `type` —
mismo patrón que el form del checkout; NO cubit propio: edita sobre el
cubit de la lista que queda debajo en el stack, mismo truco que
order_detail compartiendo OrdersCubit).

## 8. Router + guard

`auth_guard.dart`:

```dart
static const String profileAddressesRoute = '/profile/addresses';
static const String profileAddressNewRoute = '/profile/addresses/new';
// Edición — el SavedAddress viaja como extra (patrón cart/edit).
static const String profileAddressEditRoute = '/profile/addresses/edit';
```

`app_router.dart` — branch profile. Las páginas hijas en go_router
son **hermanas** de la madre en el Navigator (no heredan su
BlocProvider) — por eso orders usa singleton + `BlocProvider.value`:
`ProfileAddressesCubit` y `ProfileCubit` van `registerLazySingleton`
en DI y cada página recibe la misma instancia por `.value` (el
upsert del form escribe sobre la misma lista que queda debajo):

```dart
StatefulShellBranch(
  routes: [
    GoRoute(
      path: AuthGuard.profileRoute,
      pageBuilder: (context, state) => CustomTransitions.fade(
        state,
        BlocProvider.value(
          value: locator<ProfileCubit>(),
          child: const ProfileScreen(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'addresses',
          pageBuilder: (context, state) => CustomTransitions.slideUp(
            state,
            BlocProvider.value(
              value: locator<ProfileAddressesCubit>(),
              child: const ProfileAddressesScreen(),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              pageBuilder: (context, state) => CustomTransitions.slideUp(
                state,
                BlocProvider.value(
                  value: locator<ProfileAddressesCubit>(),
                  child: const AddressFormScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'edit',
              redirect: (context, state) => state.extra is SavedAddress
                  ? null
                  : AuthGuard.profileAddressesRoute,
              pageBuilder: (context, state) => CustomTransitions.slideUp(
                state,
                BlocProvider.value(
                  value: locator<ProfileAddressesCubit>(),
                  child: AddressFormScreen(
                    editing: state.extra! as SavedAddress,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
),
```

`setup_di.dart`: `registerLazySingleton<ProfileCubit>` y
`registerLazySingleton<ProfileAddressesCubit>` (mismo patrón
OrdersCubit §027 — en fase 2 el refresh al entrar lo gatilla
`..load()` en el pageBuilder como hace orders).

`setup_di.dart`: `registerFactory<ProfileCubit>` y
`registerFactory<ProfileAddressesCubit>` (constructores vacíos en
fase 1 — fase 2 inyecta use-cases).

## 9. ARB — claves nuevas (es + en)

| Clave | es |
|-------|----|
| `profileTitle` | "Perfil" |
| `profileAddressesRow` | "Mis direcciones" |
| `profileAddressesCount` | plural: `=0 "Sin direcciones"`, `one "{count} guardada"`, `other "{count} guardadas"` |
| `profileReferralTitle` | "Tu código de referido" |
| `profileCopyCode` | "Copiar código" |
| `profileCopiedToast` | "Código copiado" |
| `profileLogoutRow` | "Cerrar sesión" |
| `profileLogoutConfirmTitle` | "¿Cerrar sesión?" |
| `profileLogoutConfirmBody` | "Tendrás que iniciar sesión de nuevo para pedir." |
| `profileLogoutConfirmAction` | "Cerrar sesión" |
| `profileCancelAction` | "Cancelar" |
| `profileSupportRow` | "Soporte" |
| `supportDialogTitle` | "Soporte" |
| `supportDialogBody` | "Escríbenos al WhatsApp del local:" |
| `supportDialogClose` | "Cerrar" |
| `addressesTitle` | "Mis direcciones" |
| `addressDefaultBadge` | "Predeterminada" |
| `addressMakeDefault` | "Marcar predeterminada" |
| `addressDelete` | "Eliminar" |
| `addressDeleteConfirmTitle` | "¿Eliminar esta dirección?" |
| `addressDeleteConfirmBody` | "La quitarás de tus direcciones guardadas." |
| `addressDeleteConfirmAction` | "Eliminar" |
| `addressesEmpty` | "Sin direcciones guardadas" |
| `addressesEmptyHint` | "La próxima vez que pidas a domicilio puedes guardar una." |
| `addressesNewCta` | "Nueva dirección" |
| `addressesNewTitle` | "Nueva dirección" |
| `addressesEditTitle` | "Editar dirección" |
| `addressesLandmarkLabel` | "Punto de referencia" |
| `addressesLandmarkRequired` | "Cuéntanos el punto de referencia" |
| `addressesNeighborhoodLabel` | "Barrio o sector (opcional)" |
| `addressesLabelLabel` | "Nombre de la dirección" |
| `addressesLabelRequired` | "Ponle un nombre" |
| `addressFormSave` | "Guardar" |

## Orden de aplicación

1. `saved_address.dart` — `isDefault` + `copyWith` (aditivo)
2. ARB claves (es + en) + `flutter gen-l10n`
3. States + cubits (mock)
4. Widgets (identity, referral, menu row, address tile, support +
   logout dialogs)
5. Screens (profile + addresses + address_form)
6. Router + guard + DI (singletons)
7. Widget tests + cubit tests (3 pantallas + upsert/markDefault/delete)
8. `flutter analyze` + `flutter test` (sanity del implementador)

## Verificación del implementador

- `flutter analyze` limpio · tests nuevos verdes.
- Revisor-estético + revisor-ui sobre capturas del emulador (gate de
  diseño de la casa) — identidad, jerarquía, estados vacíos, diálogo.
- **La verificación completa y commits esperan OK visual del usuario**.

## Pendientes que deja la fase (ciclos de integración)

- §031 `GET /auth/me` → perfil real (extiende `User` con
  `referralCode`, `createdAt` si hace falta; cubit real con
  `AuthSession.currentUser` como primer render + refresh silencioso).
- §032 `GET /addresses` + `POST` + `PATCH :id` (campos y
  `{isDefault:true}`) + `DELETE :id` → gestión completa real
  (optimista con rollback; borrar la default re-fetch — el backend
  hace heredar otra; crear/editar refresca la lista default-primero).
- §033 `POST /auth/logout` → logout real (datasource + repo + use-case
  + `markLoggedOut` + `clearSession` + `context.go('/login')`;
  best-effort: la sesión local se limpia aunque el 204 falle —
  decisión usuario).
- Soporte: `store_settings.support_phone` (backend pendiente — hoy el
  número es placeholder; si se decide canal real puede ser url_launcher
  a WhatsApp).
- Compartir código con `share_plus`, sección "Panel del local" para
  `role=admin` — pendientes declarados, no de esta serie.
- Integración de la ampliación §030.1: `PATCH /auth/me` (datos),
  endpoint de cambio de contraseña, `GET /store/config` completo
  (entidad `StoreInfo` ya queda creada en domain) — backend pendiente
  registrado en `pcalientes_backend/pendientes/013`.

---

# Ampliación §030.1 — 4 funcionalidades más (decisión usuario)

Tras ver el Perfil base, el usuario escogió las 4 funcionalidades de la
lista ofrecida — el tab crece de "identidad + direcciones" a perfil
completo del cliente. Mismo criterio de fase: **presentación con mocks**;
los endpoints que no existen se registran como pendientes del backend.

## Qué se agrega

1. **Fila "Mis datos"** (`Icons.badge_outlined`) → `/profile/data` →
   `ProfileDataScreen` — form pre-llenado del usuario mock:
   `firstName`*, `secondName`, `firstLastName`*, `secondLastName`,
   `phone`. **Email visible pero read-only** (es la identidad de la
   cuenta — se muestra gris como campo deshabilitado, decisión de
   fase: el endpoint futuro tampoco lo cambiaría sin re-verificación).
   Guardar → `ProfileCubit.updateUser(user)` (mutación mock) + pop +
   `AppToast` "Datos actualizados". Validación inline: nombre y
   primer apellido requeridos, teléfono 10 dígitos si se diligencia.
2. **Fila "El local"** (`Icons.storefront_outlined`) → `/profile/store`
   → `ProfileStoreScreen` — card con nombre del local + **chip de
   estado REAL** (`BlocBuilder<StoreStatusCubit, StoreOpenState>` —
   el singleton §029 ya consulta `/store/config`; dato real gratis),
   lista de `weeklyHours` (7 filas día/abre–cierra/"Cerrado", la de
   hoy resaltada), filas `address` y `phone` (con copiar, patrón del
   diálogo Soporte). Datos mock vía `ProfileStoreCubit` sobre la
   entidad nueva `StoreInfo` (vive en `features/store/domain/entities/`
   — el contrato del backend ya existe; en integración la feature
   store gana `GetStoreInfoUseCase` sin tocar la pantalla).
3. **Tarjeta de referido → `ProfileLoyaltyCard`** (reemplaza
   `profile_referral_card.dart`): headline puntos (`titleLarge` w800
   "120 puntos") + copy de voz "Tu manada te premia", código "Tu
   código para la manada" + copiar (idéntico patrón Clipboard+toast),
   y "N personas ya se sumaron con tu código" (`referredCount`).
   `ProfileState` gana `loyaltyPoints: int` + `referredCount: int`
   (mocks 120 / 2). El backend de loyalty es módulo futuro — los
   campos del state ya quedan con la forma real.
4. **Fila "Cambiar contraseña"** (`Icons.lock_outline`) →
   `/profile/password` → `ProfilePasswordScreen` — 3 campos obscure:
   actual, nueva (min. igual a la regla de registro — verificar el
   DTO de `POST /auth/register` en implementación y replicar),
   confirmar (debe coincidir). Validación inline + toggles de
   visibilidad. Guardar → mock: toast "Contraseña actualizada" + pop.
   Backend gap → `pendientes/013` (`POST /auth/change-password`
   `{currentPassword, newPassword}` → 204; 400 si la actual no es).

## Layout resultante del tab

Secciones con label sutil (`bodySmall` onSurfaceVariant w600, padding
14/8 — nuevo widget `ProfileSectionLabel`):

```
Perfil (scrolling title)
├── ProfileIdentityCard
├── ProfileLoyaltyCard          (puntos + código + referidos)
├── Mi cuenta
│   ├── Mis datos          → /profile/data
│   ├── Mis direcciones    → /profile/addresses
│   └── Cambiar contraseña → /profile/password
├── El negocio
│   ├── El local           → /profile/store
│   └── Soporte            → diálogo (sin chevron)
└── Cerrar sesión          (anclada abajo, destructiva)
```

## Resumen de cambios adicionales

| Archivo | Acción |
|---------|--------|
| `presentation/screens/profile_data_screen.dart` | **nuevo** — form datos personales |
| `presentation/screens/profile_store_screen.dart` | **nuevo** — info del local |
| `presentation/screens/profile_password_screen.dart` | **nuevo** — cambio de contraseña |
| `presentation/cubit/profile_store_cubit.dart` + `_state.dart` | **nuevo** — mock StoreInfo |
| `presentation/widgets/profile_loyalty_card.dart` | **nuevo** — reemplaza `profile_referral_card.dart` |
| `presentation/widgets/profile_referral_card.dart` | **eliminado** — el código+copiar queda dentro de loyalty |
| `presentation/widgets/profile_section_label.dart` | **nuevo** — label de sección |
| `features/store/domain/entities/store_info.dart` | **nuevo** — `StoreInfo` + `DayHours` (espejo de `StoreConfigResponseDto`: name, phone?, address?, logoUrl?, weeklyHours[7]) |
| `presentation/cubit/profile_cubit.dart` + `_state.dart` | `+updateUser(User)` mock · `+loyaltyPoints`/`referredCount` en state |
| `presentation/screens/profile_screen.dart` | secciones + filas nuevas |
| `lib/core/routes/app_router.dart` | hijas `data`, `store`, `password` (mismo patrón `BlocProvider.value` singleton) |
| `lib/core/routes/auth_guard.dart` | `profileDataRoute`, `profileStoreRoute`, `profilePasswordRoute` |
| `lib/l10n/app_es.arb` | ~35 claves nuevas |
| `test/features/profile/**` | tests de las 3 pantallas + loyalty card + updateUser |

Los forms de datos y contraseña son `StatefulWidget` autónomos (patrón
del address form — sin cubit propio); el form de datos escribe con
`context.read<ProfileCubit>().updateUser(...)` antes del pop, igual
que el form de dirección hace `upsert` sobre el singleton.

