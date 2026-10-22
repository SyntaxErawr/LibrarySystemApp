import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

class ApiService {
  late final Dio _dio;

  Future<Response<dynamic>> get(String path, {String? token}) =>
      _dio.get(path, options: _authOptions(token));

  Future<Response<dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) => _dio.post(path, data: body, options: _authOptions(token));

  Options _authOptions(String? token) => Options(
    headers: token == null ? null : {'Authorization': 'Bearer $token'},
  );

  Future<Response<dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) => _dio.patch(path, data: body, options: _authOptions(token));

  ApiService({Dio? dio}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            responseType: ResponseType.json,
            headers: {'Accept': 'application/json'},
          ),
        );
  }

  Future<bool> checkConnection() async {
    // Never log request headers, query parameters, bodies, or raw exceptions.
    final uri = Uri.parse('${ApiConfig.baseUrl}/health');
    _log(
      'GET ${uri.origin}${uri.path}; platform='
      '${kIsWeb ? 'web origin=${Uri.base.origin}' : defaultTargetPlatform.name}',
    );
    try {
      final response = await _dio.get('/health');

      final data = response.data;
      _log('HTTP ${response.statusCode}');

      if (response.statusCode == 200 &&
          data is Map &&
          data['status'] == 'ok' &&
          data['database'] == 'connected') {
        return true;
      }

      _log('Health response did not match status=ok and database=connected.');
      return false;
    } on DioException catch (e) {
      _log(
        'Dio type=${e.type.name}; HTTP ${e.response?.statusCode ?? 'unavailable'}',
      );
      final detail = switch (e.type) {
        DioExceptionType.connectionTimeout =>
          'Connection timed out after 30 seconds.',
        DioExceptionType.receiveTimeout =>
          'Receive timed out after 90 seconds; Render may be starting.',
        DioExceptionType.connectionError =>
          kIsWeb
              ? 'Browser network failure: inspect DevTools for CORS, DNS, or TLS details.'
              : 'Network connection failed: check DNS, connectivity, and TLS.',
        DioExceptionType.badCertificate => 'TLS certificate validation failed.',
        DioExceptionType.badResponse =>
          'Server returned an unsuccessful HTTP status.',
        _ => 'Request failed; inspect exception type above.',
      };
      _log(detail);
      // Only emit explicitly recognized public messages. Arbitrary server text
      // can contain credentials or internal details, even on a health endpoint.
      final data = e.response?.data;
      if (data is Map && data['message'] == 'Origin is not allowed.') {
        _log(
          'Server: Origin is not allowed. Update the backend origin allowlist.',
        );
      }
      return false;
    } catch (_) {
      _log('Unexpected health response or client error.');
      return false;
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ApiService] $message');
  }
}
