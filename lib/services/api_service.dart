import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.10:8000/api';

  static const _storage = FlutterSecureStorage();
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // =====================================================
  // AUTH OTP
  // =====================================================

  Future<void> sendOtp({
    required String telephone,
    required String role,
  }) async {
    await _dio.post('/auth/send-otp', data: {
      'telephone': telephone,
      'role': role,
    });
  }

  // prenom + nom fournis = Inscription (nouveau compte)
  // prenom + nom null   = Connexion (compte existant)
  Future<Map<String, dynamic>> verifyOtp({
    required String telephone,
    required String otp,
    required String role,
    String? prenom,
    String? nom,
  }) async {
    final res = await _dio.post('/auth/verify-otp', data: {
      'telephone': telephone,
      'otp': otp,
      'role': role,
      if (prenom != null) 'prenom': prenom,
      if (nom != null) 'nom': nom,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    await _storage.delete(key: 'auth_token');
  }

  // =====================================================
  // TOKEN
  // =====================================================

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // =====================================================
  // TONTINES
  // =====================================================

  Future<Map<String, dynamic>> getTontines() async {
    final res = await _dio.get('/tontines');
    return res.data;
  }

  Future<Map<String, dynamic>> createTontine(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/tontines', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> joinTontine(String code) async {
    final res = await _dio.post('/tontines/join-invite', data: {
      'code': code,
    });
    return res.data;
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _dio.get('/dashboard/stats');
    return res.data;
  }

  Future<Map<String, dynamic>> getDashboardActivities() async {
    final res = await _dio.get('/dashboard/activites');
    return res.data;
  }

  // =====================================================
  // COTISATIONS
  // =====================================================

  Future<Map<String, dynamic>> getCotisations(int tontineId) async {
    final res = await _dio.get(
      '/cotisations',
      queryParameters: {'tontine_id': tontineId},
    );
    return res.data;
  }

  Future<Map<String, dynamic>> payerCotisation(
      int tontineId, Map<String, dynamic> data) async {
    final res = await _dio.post(
      '/cotisations/initier',
      data: {
        'tontine_id': tontineId,
        ...data,
      },
    );
    return res.data;
  }

  // =====================================================
  // SUTURA
  // =====================================================

  Future<Map<String, dynamic>> getSuturas(int tontineId) async {
    final res = await _dio.get('/sutura');
    return res.data;
  }

  Future<Map<String, dynamic>> voterSutura(int id) async {
    final res = await _dio.post('/sutura/$id/voter');
    return res.data;
  }

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _dio.get('/notifications');
    return res.data;
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.post('/notifications/$id/lire');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.post('/notifications/lire-toutes');
  }

  // =====================================================
  // EXTRA
  // =====================================================

  Future<Map<String, dynamic>> getTontineById(int id) async {
    final res = await _dio.get('/tontines/$id');
    return res.data;
  }
}