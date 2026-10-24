import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';

/// The one HTTP client for the backend.
///
/// Every request gets:
///  - the base URL (from Remote Config, so the backend can be repointed),
///  - the signed-in user's Firebase ID token (the backend's only proof of who
///    you are),
///  - `X-Client: mobile-app/<version> (<platform>)`, so the audit trail can tell
///    the app from the admin panel.
///
/// Paths are relative to the API root, e.g. `client.get('/conclaves')`.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _clientTag;

  late final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConfig.baseUrl;
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              options.headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
            } catch (e) {
              debugPrint('Could not get ID token: $e');
            }
          }
          options.headers['X-Client'] = await _tag();
          handler.next(options);
        },
      ),
    );

  Future<String> _tag() async {
    if (_clientTag != null) return _clientTag!;
    try {
      final info = await PackageInfo.fromPlatform();
      _clientTag = 'mobile-app/${info.version}+${info.buildNumber} (${defaultTargetPlatform.name})';
    } catch (_) {
      _clientTag = 'mobile-app (${defaultTargetPlatform.name})';
    }
    return _clientTag!;
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await _guard(() => dio.get(path));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await _guard(() => dio.get(path));
    return List<dynamic>.from(res.data as List);
  }

  Future<Map<String, dynamic>> send(String method, String path, [Object? body]) async {
    final res = await _guard(() => dio.request(path, data: body, options: Options(method: method)));
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// A failed backend call with a message fit to show a member. `requestId`
/// matches the server's audit trail — useful in a support message.
class ApiException implements Exception {
  final int? status;
  final String message;
  final String? requestId;
  final Map<String, dynamic> details;

  ApiException(this.message, {this.status, this.requestId, this.details = const {}});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return ApiException(
        data['error'] as String,
        status: e.response?.statusCode,
        requestId: data['requestId'] as String?,
        details: Map<String, dynamic>.from(data),
      );
    }
    final offline = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    return ApiException(
      offline ? "Can't reach the server — check your connection." : 'Something went wrong. Please try again.',
      status: e.response?.statusCode,
    );
  }

  /// True when the device simply couldn't reach the server (no response at all).
  bool get isOffline => status == null;

  @override
  String toString() => message;
}
