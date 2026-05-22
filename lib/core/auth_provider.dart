import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/usuario.dart';
import 'api_service.dart';
import 'notification_service.dart';
export 'api_service.dart' show ApiException;

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  Usuario? _usuario;
  bool     _loading = false;
  String?  _error;

  Usuario? get usuario  => _usuario;
  bool     get loading  => _loading;
  String?  get error    => _error;
  bool     get loggedIn => _usuario != null;

  Future<void> login(String email, String clave) async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final data = await ApiService().login(email, clave);
      await _storage.write(key: 'usuario', value: jsonEncode(data));
      _usuario = Usuario.fromJson(data);
      _registerFcmToken();
    } catch (e) {
      _error = _parseError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _registerFcmToken() {
    NotificationService().getToken().then((token) {
      if (token != null) ApiService().updateFcmToken(token);
    });
    NotificationService().onTokenRefresh.listen((token) {
      ApiService().updateFcmToken(token);
    });
  }

  // Restaura la sesión desde almacenamiento local sin necesitar internet.
  // Verifica el token en segundo plano y renueva automáticamente si venció.
  Future<bool> tryAutoLogin() async {
    _loading = true;
    notifyListeners();

    try {
      final userJson = await _storage.read(key: 'usuario');
      if (userJson == null) {
        _loading = false;
        notifyListeners();
        return false;
      }
      _usuario = Usuario.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _loading = false;
      notifyListeners();

      _verifyInBackground();
      return true;
    } catch (_) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // Llama a getMe() silenciosamente. Si el access token venció, ApiService
  // lo renueva automáticamente con el refresh token. Solo cierra sesión si
  // el refresh token también expiró (401 definitivo).
  void _verifyInBackground() async {
    try {
      final data = await ApiService().getMe();
      await _storage.write(key: 'usuario', value: jsonEncode(data));
      _usuario = Usuario.fromJson(data);
      notifyListeners();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        await logout();
      }
      // Error de red u otro → mantener sesión activa
    }
  }

  Future<void> logout() async {
    await ApiService().logout();
    await _storage.delete(key: 'usuario');
    _usuario = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    if (e is ApiException) return e.message;
    return 'Error de conexión: ${e.runtimeType}';
  }
}
