/// Claves de secure storage para la sesión — únicas y compartidas entre
/// AuthLocalDataSourceImpl (escribe/lee) y AuthInterceptor (lee). Evita
/// strings mágicos duplicados entre core/ y features/auth/.
class AuthStorageKeys {
  AuthStorageKeys._();

  static const String accessToken = 'auth_access_token';
  static const String refreshToken = 'auth_refresh_token';
}
