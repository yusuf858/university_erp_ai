import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class StorageService {
  const StorageService._();
  static const StorageService instance = StorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── JWT token ────────────────────────────────────────────
  Future<void>   saveToken(String t)  => _storage.write(key: StorageKeys.jwtToken, value: t);
  Future<String?> readToken()         => _storage.read(key: StorageKeys.jwtToken);
  Future<void>   deleteToken()        => _storage.delete(key: StorageKeys.jwtToken);

  // ── Gemini key ───────────────────────────────────────────
  Future<void>   saveGeminiKey(String k) => _storage.write(key: StorageKeys.geminiApiKey, value: k);
  Future<String?> readGeminiKey()        => _storage.read(key: StorageKeys.geminiApiKey);
  Future<void>   deleteGeminiKey()       => _storage.delete(key: StorageKeys.geminiApiKey);

  // ── User info ────────────────────────────────────────────
  Future<void> saveUserInfo({
    required String role,
    required String name,
    required String userId,
    String? deptCode,
    String? deptId,
  }) async {
    await Future.wait([
      _storage.write(key: StorageKeys.userRole, value: role),
      _storage.write(key: StorageKeys.userName, value: name),
      _storage.write(key: StorageKeys.userId,   value: userId),
      if (deptCode != null)
        _storage.write(key: StorageKeys.deptCode, value: deptCode),
      if (deptId != null)
        _storage.write(key: StorageKeys.deptId, value: deptId),
    ]);
  }

  Future<String?> readRole()     => _storage.read(key: StorageKeys.userRole);
  Future<String?> readUserName() => _storage.read(key: StorageKeys.userName);
  Future<String?> readDeptCode() => _storage.read(key: StorageKeys.deptCode);

  // ── Clear all ────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();

  // ── Has valid token (non-empty only — expiry checked in AuthService) ──
  Future<bool> hasToken() async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }
}