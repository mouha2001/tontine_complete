import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Résultat de la vérification OTP dans le flux unifié :
/// - [authenticated]      : compte existant ou inscription finalisée → connecté
/// - [needsRegistration]  : nouveau numéro, profil (nom + prénom) à compléter
/// - [error]              : OTP invalide / erreur réseau
enum VerifyResult { authenticated, needsRegistration, error }

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  AuthStatus _status  = AuthStatus.unknown;
  User?      _user;
  String?    _error;
  bool       _loading = false;

  // Résultat d'un éventuel "join via code" effectué pendant l'inscription —
  // consommé une fois par l'écran d'accueil pour afficher un retour.
  String?    joinNotice;
  bool       joinNoticeOk = false;

  AuthStatus get status  => _status;
  User?      get user    => _user;
  String?    get error   => _error;
  bool       get loading => _loading;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;

  void clearJoinNotice() {
    joinNotice = null;
    joinNoticeOk = false;
  }

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

  // Étape 2 — Vérifier OTP (flux unifié connexion / inscription)
  //
  // 1er appel sans prenom/nom :
  //   - compte existant → token renvoyé → [VerifyResult.authenticated]
  //   - nouveau numéro  → le backend répond needs_registration → [VerifyResult.needsRegistration]
  // 2e appel avec prenom + nom (même OTP) → finalise l'inscription → [VerifyResult.authenticated]
  Future<VerifyResult> verifyOtp({
    required String telephone,
    required String otp,
    required String role,
    String? prenom,
    String? nom,
    String? inviteCode,
  }) async {
    _setLoading(true);
    try {
      final data = await _api.verifyOtp(
        telephone: telephone,
        otp: otp,
        role: role,
        prenom: prenom,
        nom: nom,
        inviteCode: inviteCode,
      );

      // Nouveau compte : profil à compléter (pas de token à ce stade)
      if (data['needs_registration'] == true) {
        _setLoading(false);
        return VerifyResult.needsRegistration;
      }

      final token = data['token'] ?? data['access_token'];
      if (token != null) {
        await ApiService.saveToken(token);
        _user = User.fromJson(data['user']);
        _status = AuthStatus.authenticated;

        // Résultat éventuel du join via code d'invitation à l'inscription
        final join = data['join'];
        if (join is Map && join['message'] != null) {
          joinNotice   = join['message'] as String?;
          joinNoticeOk = join['ok'] == true;
        }

        _setLoading(false);
        return VerifyResult.authenticated;
      }
      _error = 'Réponse inattendue du serveur';
    } catch (e) {
      _error = _parseError(e);
    }
    _setLoading(false);
    return VerifyResult.error;
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