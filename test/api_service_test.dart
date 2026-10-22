import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librarysystemapp/config/api_config.dart';
import 'package:librarysystemapp/services/api_service.dart';

class HealthAdapter implements HttpClientAdapter {
  HealthAdapter(this.body, this.status, {this.failure});
  final String body;
  final int status;
  final DioExceptionType? failure;
  RequestOptions? request;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    calls++;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<bool> check(HealthAdapter adapter) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ),
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return ApiService(dio: dio).checkConnection();
  }

  test('healthy backend uses the complete API health URL', () async {
    final adapter = HealthAdapter(
      '{"status":"ok","database":"connected"}',
      200,
    );
    expect(await check(adapter), isTrue);
    expect(adapter.request!.uri.toString(), '${ApiConfig.baseUrl}/health');
    expect(adapter.request!.connectTimeout, const Duration(seconds: 30));
    expect(adapter.request!.receiveTimeout, const Duration(seconds: 90));
  });

  for (final body in [
    '{"status":"ok","database":"disconnected"}',
    '{}',
    '[]',
    'invalid json',
  ]) {
    test('rejects unhealthy or malformed body: $body', () async {
      expect(await check(HealthAdapter(body, 200)), isFalse);
    });
  }

  for (final status in [403, 404, 500, 503]) {
    test('HTTP $status fails without retry', () async {
      final adapter = HealthAdapter(
        '{"message":"Origin is not allowed."}',
        status,
      );
      expect(await check(adapter), isFalse);
      expect(adapter.calls, 1);
    });
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('${type.name} fails without retry', () async {
      final adapter = HealthAdapter('', 200, failure: type);
      expect(await check(adapter), isFalse);
      expect(adapter.calls, 1);
    });
  }
}
