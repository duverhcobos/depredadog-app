# Propuesta: `errorCode` — consumo del contrato machine-readable del backend (§017)

El backend (§017, commit `434745e`) ya emite `errorCode` en cada error de dominio: `{statusCode, errorCode, message, timestamp}`. La app hoy mapea errores por `statusCode` + **string-matching del mensaje en inglés** — frágil documentado en el propio código (`e.message == 'Invalid or expired code'`, `'Email is not verified'`, `'Account is suspended'` en `auth_repository_impl`, y el comentario "400 'Invalid referral code' no se mapea: no se distingue de otros 400").

Esta propuesta conecta el contrato: `ServerException` transporta `errorCode` y cada repository impl mapea **por código, no por texto**. Los fallbacks por statusCode/mensaje se conservan detrás — si un proxy o una respuesta vieja llega sin el campo, el mapeo actual sigue funcionando.

**Ganancia UX real:** los rechazos del `POST /orders` dejan de ser genéricos — "El local está cerrado ahora" vs "Algo de tu pedido ya no está disponible" son mensajes distintos para el cliente.

Sin superficie nueva — solo textos distintos en filas/toasts de error existentes.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/network/exceptions/network_exception.dart` | `ServerException` + `errorCode` |
| `lib/core/network/implementations/dio_network_service_impl.dart` | `_mapError` extrae `errorCode` del body |
| `lib/features/checkout/domain/failures/checkout_failure.dart` | enum `OrderRejection` + campo `code` en `CheckoutOrderRejectedFailure` |
| `lib/features/checkout/data/repositories/checkout_repository_impl.dart` | mapea `errorCode` → `OrderRejection` |
| `lib/features/checkout/presentation/cubit/checkout_cubit.dart` | `_confirmErrorText` → copy dedicado por código |
| `lib/features/orders/data/repositories/orders_repository_impl.dart` | cancel rechazado claveado a `ORDER_NOT_CANCELLABLE` |
| `lib/features/orders/domain/failures/orders_failure.dart` | comentario stale (no es "español") |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | `_mapFailure` por `errorCode` primero, fallback status actual |
| `lib/l10n/app_es.arb` | 4 keys nuevas de rechazo del checkout |
| `test/**` | specs por código en los 3 repos + cubit + parse de errorCode |

---

## 1. `network_exception.dart` (archivo existente — actualización)

**Ruta:** `lib/core/network/exceptions/network_exception.dart`

**Antes:**
```dart
/// El servidor respondió con error (4xx/5xx) o timeout.
class ServerException extends NetworkException {
  const ServerException(super.message, {super.statusCode});
}
```

**Después:**
```dart
/// El servidor respondió con error (4xx/5xx) o timeout. `errorCode` es
/// el contrato machine-readable del backend (§017): solo viene en
/// errores de DomainException; null en validación/guards/5xx.
class ServerException extends NetworkException {
  const ServerException(super.message, {super.statusCode, this.errorCode});

  final String? errorCode;
}
```

## 2. `dio_network_service_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/core/network/implementations/dio_network_service_impl.dart`

**Antes:**
```dart
    final serverMessage = e.response?.data is Map<String, dynamic>
        ? (e.response!.data as Map<String, dynamic>)['message']
        : null;
    _logger.warning(
      'HTTP ${e.requestOptions.method} ${e.requestOptions.path} → $status',
      tag: 'Network',
    );
    return ServerException(
      serverMessage is String
          ? serverMessage
          : (serverMessage is List && serverMessage.isNotEmpty
                ? serverMessage.first.toString()
                : 'Request failed'),
      statusCode: status,
    );
```

**Después:**
```dart
    final body = e.response?.data is Map<String, dynamic>
        ? e.response!.data as Map<String, dynamic>
        : null;
    final serverMessage = body?['message'];
    _logger.warning(
      'HTTP ${e.requestOptions.method} ${e.requestOptions.path} → $status',
      tag: 'Network',
    );
    return ServerException(
      serverMessage is String
          ? serverMessage
          : (serverMessage is List && serverMessage.isNotEmpty
                ? serverMessage.first.toString()
                : 'Request failed'),
      statusCode: status,
      errorCode: body?['errorCode'] as String?,
    );
```

## 3. `checkout_failure.dart` (archivo existente — actualización)

**Ruta:** `lib/features/checkout/domain/failures/checkout_failure.dart`

**Antes:**
```dart
/// POST /orders rechazado por el backend (400/409 — validación o
/// regla de negocio: local cerrado, producto agotado, reemplazo
/// inválido). `message` es el texto del servidor — llega en INGLÉS y
/// sin `code` para distinguir casos, así que la UI muestra copy
/// genérico l10n y conserva esto solo para logging (revisor §027).
final class CheckoutOrderRejectedFailure extends CheckoutFailure {
  const CheckoutOrderRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
```

**Después:**
```dart
/// Motivo del rechazo del POST /orders — se resuelve del `errorCode`
/// del backend (§017/§028). `unknown` cubre código ausente (backend
/// viejo/proxy) o uno que el cliente aún no conoce.
enum OrderRejection {
  storeClosed,
  minOrderAmount,
  catalogViolation,
  invalidOrderData,
  unknown,
}

/// POST /orders rechazado por el backend (400/409 — validación o
/// regla de negocio). `message` se conserva solo para logging (llega
/// en inglés); la UI hace pattern-matching en `code` para elegir su
/// copy dedicado.
final class CheckoutOrderRejectedFailure extends CheckoutFailure {
  const CheckoutOrderRejectedFailure(this.message, {required this.code});

  final String message;
  final OrderRejection code;

  @override
  List<Object?> get props => [message, code];
}
```

## 4. `checkout_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/checkout/data/repositories/checkout_repository_impl.dart`

**Antes (fragmento `_mapOrderFailure`):**
```dart
    if (e is ServerException && const {400, 409, 422}.contains(e.statusCode)) {
      return CheckoutOrderRejectedFailure(e.message);
    }
```

**Después:**
```dart
    if (e is ServerException && const {400, 409, 422}.contains(e.statusCode)) {
      return CheckoutOrderRejectedFailure(
        e.message,
        code: _parseRejection(e.errorCode),
      );
    }
```

**Y el helper nuevo al final de la clase:**
```dart
  /// `errorCode` del backend (§017) → motivo tipado. Código ausente o
  /// desconocido → `unknown` (el copy genérico sigue sirviendo).
  OrderRejection _parseRejection(String? errorCode) {
    return switch (errorCode) {
      'STORE_CLOSED' => OrderRejection.storeClosed,
      'MIN_ORDER_AMOUNT' => OrderRejection.minOrderAmount,
      'ORDER_CATALOG_VIOLATION' => OrderRejection.catalogViolation,
      'INVALID_ORDER_DATA' => OrderRejection.invalidOrderData,
      _ => OrderRejection.unknown,
    };
  }
```

## 5. `checkout_cubit.dart` (archivo existente — actualización)

**Ruta:** `lib/features/checkout/presentation/cubit/checkout_cubit.dart`

**Antes:**
```dart
  /// Texto de la fila de error — siempre l10n propio: los mensajes de
  /// dominio del backend llegan en inglés (revisor §027: la premisa
  /// "español producto" era falsa) y no hay `code` para distinguir
  /// casos — el rechazo muestra copy genérico dedicado.
  String _confirmErrorText(CheckoutFailure failure) {
    final l10n = AppLocalizationsEs();
    return switch (failure) {
      CheckoutOrderRejectedFailure() => l10n.checkoutOrderRejected,
      CheckoutOfflineFailure() => l10n.checkoutOrderOffline,
      _ => l10n.checkoutOrderFailed,
    };
  }
```

**Después:**
```dart
  /// Texto de la fila de error — siempre l10n propio: `code` tipa el
  /// rechazo (§028, `errorCode` del backend §017) y cada motivo tiene
  /// su copy dedicado; código ausente/desconocido → genérico.
  String _confirmErrorText(CheckoutFailure failure) {
    final l10n = AppLocalizationsEs();
    return switch (failure) {
      CheckoutOrderRejectedFailure(:final code) => switch (code) {
        OrderRejection.storeClosed => l10n.checkoutRejectStoreClosed,
        OrderRejection.minOrderAmount => l10n.checkoutRejectMinOrder,
        OrderRejection.catalogViolation => l10n.checkoutRejectCatalog,
        OrderRejection.invalidOrderData => l10n.checkoutRejectInvalidData,
        OrderRejection.unknown => l10n.checkoutOrderRejected,
      },
      CheckoutOfflineFailure() => l10n.checkoutOrderOffline,
      _ => l10n.checkoutOrderFailed,
    };
  }
```

(El import de `checkout_failure.dart` ya existe vía `checkout_cubit.dart` — el enum vive en el mismo archivo del failure.)

## 6. `orders_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/orders/data/repositories/orders_repository_impl.dart`

**Antes (fragmento de `cancelOrder`):**
```dart
      if (e is ServerException && e.statusCode == 409) {
        return Left(OrdersCancelRejectedFailure(e.message));
      }
```

**Después:**
```dart
      // 409 claveado al código del backend (§017/§028); el fallback por
      // statusCode cubre respuestas sin el campo (el único 409 que
      // cancel puede emitir hoy es ORDER_NOT_CANCELLABLE).
      if (e is ServerException &&
          (e.errorCode == 'ORDER_NOT_CANCELLABLE' ||
              (e.errorCode == null && e.statusCode == 409))) {
        return Left(OrdersCancelRejectedFailure(e.message));
      }
```

## 7. `orders_failure.dart` (archivo existente — comentario stale)

**Ruta:** `lib/features/orders/domain/failures/orders_failure.dart`

**Antes:**
```dart
/// POST /orders/:id/cancel rechazado (409 — ya no está pending; el
/// mensaje del servidor viene en español y se muestra tal cual).
```

**Después:**
```dart
/// POST /orders/:id/cancel rechazado (409 ORDER_NOT_CANCELLABLE — ya
/// no está pending). `message` llega en inglés y solo sirve para
/// logging; la UI muestra su copy dedicado (§027/§028).
```

## 8. `auth_repository_impl.dart` (archivo existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**
```dart
  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas — el 401 de
    // /auth/me se intercepta en restoreSession antes de llegar acá.
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    // 400 "Invalid or expired code" cubre código errado, expirado y cuenta
    // no pendiente (el backend no los distingue — anti-enumeración). Otros
    // 400 (validación de DTO) caen a Unknown — la UI ya impide formatos
    // inválidos, así que un 400 ajeno al código es un bug, no un caso UX.
    if (e.statusCode == 400 && e.message == 'Invalid or expired code') {
      return const InvalidCodeFailure();
    }
    if (e.statusCode == 403) {
      if (e.message == 'Email is not verified') {
        return const EmailNotVerifiedFailure();
      }
      if (e.message == 'Account is suspended') {
        return const AccountSuspendedFailure();
      }
    }
    // 409 solo lo emite /auth/register y solo significa "Email is already
    // registered" — en esta feature no hay otro 409 posible, así que el
    // mapeo va por statusCode directo (400 "Invalid referral code" no se
    // mapea: no enviamos referralCode — cae a Unknown, bug nuestro si llega).
    if (e.statusCode == 409) {
      return const EmailAlreadyRegisteredFailure();
    }
    if (e.statusCode == 429) return const TooManyAttemptsFailure();
    return UnknownAuthFailure(e.message);
  }
```

**Después:**
```dart
  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas — el 401 de
    // /auth/me se intercepta en restoreSession antes de llegar acá.
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    // errorCode del backend (§017) manda — el string-matching inglés de
    // abajo queda solo como fallback para respuestas sin el campo.
    if (e is ServerException) {
      final byCode = switch (e.errorCode) {
        'INVALID_AUTH_CODE' => const InvalidCodeFailure(),
        'EMAIL_NOT_VERIFIED' => const EmailNotVerifiedFailure(),
        'USER_SUSPENDED' => const AccountSuspendedFailure(),
        'EMAIL_ALREADY_REGISTERED' => const EmailAlreadyRegisteredFailure(),
        _ => null,
      };
      if (byCode != null) return byCode;
    }
    // Fallbacks por statusCode/mensaje (respuestas sin errorCode):
    // 400 "Invalid or expired code" cubre código errado, expirado y cuenta
    // no pendiente (el backend no los distingue — anti-enumeración).
    if (e.statusCode == 400 && e.message == 'Invalid or expired code') {
      return const InvalidCodeFailure();
    }
    if (e.statusCode == 403) {
      if (e.message == 'Email is not verified') {
        return const EmailNotVerifiedFailure();
      }
      if (e.message == 'Account is suspended') {
        return const AccountSuspendedFailure();
      }
    }
    if (e.statusCode == 409) {
      return const EmailAlreadyRegisteredFailure();
    }
    if (e.statusCode == 429) return const TooManyAttemptsFailure();
    return UnknownAuthFailure(e.message);
  }
```

## 9. `app_es.arb` (archivo existente — actualización)

**Ruta:** `lib/l10n/app_es.arb`

Después de `"@checkoutOrderRejected"`:
```json
  "checkoutRejectStoreClosed": "El local está cerrado ahora — intenta en el horario de atención",
  "@checkoutRejectStoreClosed": {
    "description": "POST /orders rechazado con STORE_CLOSED (§028)"
  },
  "checkoutRejectMinOrder": "El pedido no llega al mínimo a domicilio — súmele algo más",
  "@checkoutRejectMinOrder": {
    "description": "POST /orders rechazado con MIN_ORDER_AMOUNT (§028)"
  },
  "checkoutRejectCatalog": "Algo de tu pedido ya no está disponible — revísalo e inténtalo de nuevo",
  "@checkoutRejectCatalog": {
    "description": "POST /orders rechazado con ORDER_CATALOG_VIOLATION — opción agotada/removida/inválida (§028)"
  },
  "checkoutRejectInvalidData": "Revisa los datos del pedido e inténtalo de nuevo",
  "@checkoutRejectInvalidData": {
    "description": "POST /orders rechazado con INVALID_ORDER_DATA (§028)"
  },
```

Luego `flutter gen-l10n`.

## 10. Tests (archivos existentes + nuevos asserts)

- **`test/features/auth/data/repositories/auth_repository_impl_test.dart`**: por cada `errorCode` → failure correcta (INVALID_AUTH_CODE→InvalidCode, EMAIL_NOT_VERIFIED→EmailNotVerified, USER_SUSPENDED→AccountSuspended, EMAIL_ALREADY_REGISTERED→EmailAlreadyRegistered); caso sin `errorCode` pero con mensaje inglés legacy → el fallback sigue mapeando igual.
- **`test/features/checkout/data/repositories/checkout_repository_impl_test.dart`**: 409 con `errorCode: 'STORE_CLOSED'` → `CheckoutOrderRejectedFailure(code: storeClosed)`; sin `errorCode` → `code: unknown`.
- **`test/features/checkout/presentation/cubit/checkout_cubit_test.dart`**: cada `OrderRejection` → su copy dedicado en `confirmError` (`unknown` → el genérico).
- **`test/features/orders/data/repositories/orders_repository_impl_test.dart`**: cancel 409 con `ORDER_NOT_CANCELLABLE` → `OrdersCancelRejectedFailure`; 409 SIN errorCode → mismo failure (fallback); 409 con OTRO código → `OrdersServerFailure` (no finge "ya lo tomó").
- **`test/core/network/`**: si existe spec del `_mapError`, agregar assert de `errorCode` transportado; si no, el assert queda cubierto por los specs de repo que inyectan la excepción.

---

## Orden de aplicación

1. `network_exception.dart` + `dio_network_service_impl.dart` (el contrato viaja)
2. `checkout_failure.dart` (enum) → `checkout_repository_impl.dart` → `checkout_cubit.dart` → `app_es.arb` + `gen-l10n`
3. `orders_repository_impl.dart` + `orders_failure.dart` (comentario)
4. `auth_repository_impl.dart`
5. Tests por archivo
6. `flutter analyze` + `flutter test` → emulador (casos de rechazo visibles: login con clave errada muestra el copy dedicado idéntico, local cerrado muestra su copy) → aprobación → revisor → commit

Fuera de alcance (documentado): `InvalidReferralCodeFailure` no se agrega — la app no envía `referralCode` hoy; cuando el flujo exista se mapea con su código ya disponible. Los códigos de sesión (`SESSION_NOT_FOUND`, `COMPROMISED_SESSION`, `INVALID_REFRESH_TOKEN`) no generan copy — el refresh/logout silencioso los maneja antes de la UI.

## Anexo — encuesta de revisión (registrado)

| # | Pregunta | Respuesta del usuario |
|---|----------|------------------------|
| 1 | ¿Fallbacks statusCode/mensaje cuando errorCode mapea? | **Conservar detrás** — código primero, fallback después; respuestas sin el campo siguen mapeando igual que hoy. |
| 2 | ¿Enum tipado en domain/failures o string plano? | **Enum `OrderRejection` tipado** — traducción en el borde data, pattern-matching exhaustivo en el cubit. |
| 3 | ¿409 sin `errorCode` en cancelar sigue siendo "ya no cancelable"? | **Sí, fallback** — el único 409 que cancel emite hoy es ese; 409 con OTRO código → `OrdersServerFailure` genérico. |

**Estado:** propuesta revisada y aprobada — lista para implementar.
