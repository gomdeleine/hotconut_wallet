import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorageDelegate {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<List<String>> getAllKeys();
  Future<void> deleteAll();
}

class FlutterSecureStorageDelegate implements SecureStorageDelegate {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  @override
  Future<void> write({required String key, required String value}) => _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<List<String>> getAllKeys() async {
    final allValues = await _storage.readAll();
    return allValues.keys.toList();
  }

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

@visibleForTesting
class InMemorySecureStorageDelegate implements SecureStorageDelegate {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<List<String>> getAllKeys() async => _store.keys.toList();

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class SecureStorageRepository {
  final SecureStorageDelegate _delegate;

  SecureStorageRepository._(this._delegate);

  static final SecureStorageRepository _instance = SecureStorageRepository._(FlutterSecureStorageDelegate());

  factory SecureStorageRepository() => _instance;

  @visibleForTesting
  factory SecureStorageRepository.inMemory() => SecureStorageRepository._(InMemorySecureStorageDelegate());

  Future<void> write({required String key, required String value}) => _delegate.write(key: key, value: value);

  Future<String?> read({required String key}) => _delegate.read(key: key);

  Future<void> delete({required String key}) => _delegate.delete(key: key);

  Future<List<String>> getAllKeys() => _delegate.getAllKeys();

  Future<void> deleteAll() => _delegate.deleteAll();
}
