/// Puerto del SDK de Google Sign-In (no es un datasource HTTP — envuelve el
/// plugin `google_sign_in`). La implementación es la única que conoce el
/// paquete; el repository depende de esta interfaz como de las demás.
abstract class IGoogleSignInGateway {
  /// Lanza el flujo nativo y devuelve el idToken listo para el backend.
  /// `null` = el usuario canceló el selector de cuentas (caso silencioso —
  /// la UI no muestra nada). Errores del SDK (sin Play Services, init
  /// fallida, red del propio flujo) propagan como excepción — el repository
  /// los traduce a failure genérico.
  Future<String?> getIdToken();
}
