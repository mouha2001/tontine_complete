import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  AuthStatus _status  = AuthStatus.unknown;
  User?      _user;
  String?    _error;
  bool       _loading = false;

  AuthStatus get status  => _status;
  User?      get user    => _user;
  String?    get error   => _error;
  bool       get loading => _loading;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;

  // Vérification token au démarrage
  Future<void> checkAuth() async {
    final token = await ApiService.getToken();
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.getMe();
      _user = User.fromJson(data['user'] ?? data);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await ApiService.clearToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // Étape 1 — Envoyer OTP (Login ET Register)
  Future<bool> sendOtp(String telephone, String role) async {
    _setLoading(true);
    try {
      await _api.sendOtp(telephone: telephone, role: role);
      _setLoading(false);
      return true;
    } catch (e) {
      _error = _parseError(e);
      _setLoading(false);
      return false;
    }
  }

  // Étape 2 — Vérifier OTP
  // prenom + nom fournis = Inscription
  // prenom + nom null   = Connexion
  Future<bool> verifyOtp({
    required String telephone,
    required String otp,
    required String role,
    String? prenom,
    String? nom,
  }) async {
    _setLoading(true);
    try {
      final data = await _api.verifyOtp(
        telephone: telephone,
        otp: otp,
        role: role,
        prenom: prenom,
        nom: nom,
      );
      final token = data['token'] ?? data['access_token'];
      if (token != null) {
        await ApiService.saveToken(token);
        _user = User.fromJson(data['user']);
        _status = AuthStatus.authenticated;
        _setLoading(false);
        return true;
      }
      _error = 'Réponse inattendue du serveur';
    } catch (e) {
      _error = _parseError(e);
    }
    _setLoading(false);
    return false;
  }

  Future<void> logout() async {
    await _api.logout();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _loading = val;
    if (val) _error = null;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('404')) return 'Numéro introuvable. Inscrivez-vous d\'abord.';
    if (msg.contains('422')) return 'Code OTP incorrect ou expiré';
    if (msg.contains('429')) return 'Trop de tentatives, réessayez plus tard';
    if (msg.contains('SocketException') || msg.contains('Failed host lookup'))
      return 'Impossible de joindre le serveur';
    if (msg.contains('timeout')) return 'Le serveur ne répond pas';
    return 'Une erreur est survenue';
  }
}