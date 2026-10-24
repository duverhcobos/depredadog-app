/// Puerto de almacenamiento seguro (keychain/keystore). La feature auth lo
/// usa para tokens; nunca deleteAll() salvo intención explícita — borrar
/// solo claves propias (environments-secrets).
abstract class ISecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteKeys(List<String> keys);
}
