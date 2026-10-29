/// Persistencia local de la sesión (secure storage). Separado del
/// datasource remoto (regla 5 SOLID — Repository orquesta ambos).
abstract class IAuthLocalDataSource {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  });

  Future<String?> readAccessToken();

  /// Borra solo las claves de auth — nunca deleteAll() (environments-secrets).
  Future<void> clearSession();
}
