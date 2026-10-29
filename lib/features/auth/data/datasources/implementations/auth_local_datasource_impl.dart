import '../../../../../core/auth/auth_storage_keys.dart';
import '../../../../../core/storage/interfaces/i_secure_storage.dart';
import '../interfaces/i_auth_local_datasource.dart';

/// SOLID (SRP): única clase que sabe las claves de storage de la sesión.
class AuthLocalDataSourceImpl implements IAuthLocalDataSource {
  const AuthLocalDataSourceImpl({required this._secureStorage});

  final ISecureStorage _secureStorage;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(AuthStorageKeys.accessToken, accessToken);
    await _secureStorage.write(AuthStorageKeys.refreshToken, refreshToken);
  }

  @override
  Future<String?> readAccessToken() =>
      _secureStorage.read(AuthStorageKeys.accessToken);

  @override
  Future<void> clearSession() => _secureStorage.deleteKeys([
    AuthStorageKeys.accessToken,
    AuthStorageKeys.refreshToken,
  ]);
}
