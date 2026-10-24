import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../interfaces/i_secure_storage.dart';

class FlutterSecureStorageImpl implements ISecureStorage {
  // flutter_secure_storage 11.x: el cifrado (cipher storage propio, sucesor
  // de EncryptedSharedPreferences) es el default — no requiere opt-in.
  FlutterSecureStorageImpl()
    : _storage = const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteKeys(List<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }
}
