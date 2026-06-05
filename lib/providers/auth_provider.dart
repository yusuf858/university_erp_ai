import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { idle, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status  = AuthStatus.idle;
  UserModel? _user;
  String     _error   = '';

  AuthStatus get status        => _status;
  UserModel? get currentUser   => _user;
  String     get error         => _error;
  bool       get isLoggedIn    => _user != null;
  bool       get isLoading     => _status == AuthStatus.loading;

  Future<void> checkSavedToken() async {
    _setStatus(AuthStatus.loading);
    try {
      final token = await StorageService.instance.readToken();
      if (token == null || token.isEmpty) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }
      final payload = _decodePayload(token);
      if (payload == null) {
        await StorageService.instance.clearAll();
        _setStatus(AuthStatus.unauthenticated);
        return;
      }
      final exp = payload['exp'] as int? ?? 0;
      if (exp < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        await StorageService.instance.clearAll();
        _setStatus(AuthStatus.unauthenticated);
        return;
      }
      _user = UserModel.fromJson(payload, token);
      _setStatus(AuthStatus.authenticated);
    } catch (_) {
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    _error = '';
    _setStatus(AuthStatus.loading);
    try {
      final response = await ApiService.instance.login(email, password);
      final data     = response['data'] as Map<String, dynamic>;
      final token    = data['token'] as String;
      final payload  = _decodePayload(token)!;

      _user = UserModel.fromJson({...payload, ...data}, token);

      await StorageService.instance.saveToken(token);
      await StorageService.instance.saveUserInfo(
        role:     _user!.role,
        name:     _user!.name,
        userId:   _user!.id.toString(),
        deptCode: _user!.departmentCode,
      );

      _setStatus(AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setStatus(AuthStatus.error);
      return false;
    } catch (e) {
      // DEBUG: Show actual network exception
      _error = 'Network Error: ${e.toString().split('\n').first}';
      debugPrint('LOGIN_ERROR: $e');
      _setStatus(AuthStatus.error);
      return false;
    }
  }

  Future<void> logout() async {
    await StorageService.instance.clearAll();
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  Map<String, dynamic>? _decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded    = utf8.decode(base64.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }
}
