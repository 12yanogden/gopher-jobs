import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over API token persistence (secure storage on device).
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String? value);
}

/// [FlutterSecureStorage]-backed token store.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'gopher_jobs_api_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
  }
}

/// In-memory token store for tests.
class InMemoryTokenStorage implements TokenStorage {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String? value) async {
    _value = (value == null || value.isEmpty) ? null : value;
  }
}
