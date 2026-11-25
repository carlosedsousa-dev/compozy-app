import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compozy_app/core/network/api_exceptions.dart';
import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/core/network/health_checker.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final int statusCode;
  final String responseBody;
  final DioExceptionType? throwType;
  final String? throwErrorMessage;

  _MockHttpClientAdapter({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.throwType,
    this.throwErrorMessage,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic decodeBody(String body) {
      try {
        return body.isNotEmpty ? jsonDecode(body) : null;
      } catch (_) {
        return body;
      }
    }

    if (throwType != null) {
      throw DioException(
        requestOptions: options,
        error: throwErrorMessage ?? 'Simulated error',
        type: throwType!,
        response: statusCode != 200
            ? Response(
                requestOptions: options,
                statusCode: statusCode,
                data: decodeBody(responseBody),
              )
            : null,
      );
    }

    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: decodeBody(responseBody),
        ),
      );
    }

    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CompozyApiClient', () {
    test('testApiClientGetSuccess - successfully fetches and parses JSON map', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: '{"sessions": [{"id": "s1", "name": "test"}]}',
      );
      final client = CompozyApiClient(dio: dio);

      final result = await client.get('/api/sessions');

      expect(result, isA<Map<String, dynamic>>());
      expect(result['sessions'], isList);
      expect((result['sessions'] as List).first['id'], equals('s1'));
    });

    test('testApiClientPostSuccess - dispatches POST data and decodes response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: '{"status": "queued", "turn_id": "turn_123"}',
      );
      final client = CompozyApiClient(dio: dio);

      final result = await client.post(
        '/api/sessions/s1/prompt',
        data: {'prompt': 'hello agent'},
      );

      expect(result['status'], equals('queued'));
      expect(result['turn_id'], equals('turn_123'));
    });

    // UT-002: Network error returns healthy: false and throws CompozyApiException
    test('testApiClientError', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        throwType: DioExceptionType.connectionError,
        throwErrorMessage: 'Connection refused',
      );
      final client = CompozyApiClient(dio: dio);

      // Verify client throws CompozyApiException (CompozyNetworkException)
      expect(
        () => client.get('/api/openapi.json'),
        throwsA(isA<CompozyApiException>()),
      );

      // Verify that HealthChecker using client returns healthy: false on network error
      final healthChecker = HealthChecker(apiClient: client);
      final isHealthy = await healthChecker.checkHealth();
      expect(isHealthy, isFalse);
    });

    // UT-003: Connection timeout throws TimeoutException
    test('testApiClientTimeout', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:2123',
        connectTimeout: const Duration(seconds: 5),
      ));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        throwType: DioExceptionType.connectionTimeout,
        throwErrorMessage: 'Connection timed out after 5000ms',
      );
      final client = CompozyApiClient(dio: dio);

      // Throws TimeoutException and CompozyApiException
      expect(
        () => client.get('/api/sessions'),
        throwsA(isA<TimeoutException>()),
      );
      expect(
        () => client.get('/api/sessions'),
        throwsA(isA<CompozyApiException>()),
      );
      expect(
        () => client.get('/api/sessions'),
        throwsA(isA<CompozyTimeoutException>()),
      );
    });

    // UT-004: Daemon 500 throws CompozyApiException
    test('testApiClientServerError', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 500,
        responseBody: jsonEncode({
          'code': 'internal_server_error',
          'error': 'Daemon database lock contention',
          'details': {'retryable': false},
        }),
      );
      final client = CompozyApiClient(dio: dio);

      try {
        await client.get('/api/sessions');
        fail('Should have thrown CompozyApiException');
      } on CompozyApiException catch (e) {
        expect(e, isA<CompozyServerException>());
        expect(e.statusCode, equals(500));
        expect(e.code, equals('internal_server_error'));
        expect(e.message, equals('Daemon database lock contention'));
        expect(e.details, equals({'retryable': false}));
      }
    });

    test('maps 409 session busy to SessionBusyException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 409,
        responseBody: jsonEncode({
          'code': 'session_busy',
          'error': 'Session is currently running a turn',
        }),
      );
      final client = CompozyApiClient(dio: dio);

      expect(
        () => client.post('/api/sessions/s1/prompt', data: {'prompt': 'hi'}),
        throwsA(isA<SessionBusyException>()),
      );
    });

    test('respects custom base URL and authorization header', () {
      final client = CompozyApiClient(
        baseUrl: 'http://192.168.1.100:2123',
        appToken: 'secret_token_abc',
      );

      expect(client.baseUrl, equals('http://192.168.1.100:2123'));
    });

    test('handles non-JSON 500 error gracefully', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 500,
        responseBody: 'Internal Server Error (Crash)',
      );
      final client = CompozyApiClient(dio: dio);

      try {
        await client.get('/api/sessions');
        fail('Should have thrown CompozyApiException');
      } on CompozyApiException catch (e) {
        expect(e, isA<CompozyServerException>());
        expect(e.statusCode, equals(500));
        expect(e.message, equals('Internal Server Error (Crash)'));
      }
    });

    test('supports query parameters on get', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: '{"sessions": []}',
      );
      final client = CompozyApiClient(dio: dio);

      final result = await client.get(
        '/api/sessions',
        queryParameters: {'all_workspaces': 'true', 'limit': 10},
      );

      expect(result['sessions'], isEmpty);
    });

    test('compozyApiClientProvider resolves from ProviderContainer', () {
      final container = ProviderContainer();
      final client = container.read(compozyApiClientProvider);

      expect(client, isNotNull);
      expect(client.baseUrl, equals('http://localhost:2123'));
      container.dispose();
    });
  });

  group('normalizeCompozyBaseUrl & defaultCompozyBaseUrl', () {
    test('defaultCompozyBaseUrl respects isAndroid injection seam', () {
      expect(defaultCompozyBaseUrl(isAndroid: true), equals('http://10.0.2.2:2123'));
      expect(defaultCompozyBaseUrl(isAndroid: false), equals('http://localhost:2123'));
    });

    test('blank yields platform default', () {
      expect(normalizeCompozyBaseUrl(null, isAndroid: true), equals('http://10.0.2.2:2123'));
      expect(normalizeCompozyBaseUrl('', isAndroid: true), equals('http://10.0.2.2:2123'));
      expect(normalizeCompozyBaseUrl('   ', isAndroid: true), equals('http://10.0.2.2:2123'));

      expect(normalizeCompozyBaseUrl(null, isAndroid: false), equals('http://localhost:2123'));
      expect(normalizeCompozyBaseUrl('', isAndroid: false), equals('http://localhost:2123'));
      expect(normalizeCompozyBaseUrl('   ', isAndroid: false), equals('http://localhost:2123'));
    });

    test('http://localhost:2123 + isAndroid -> http://10.0.2.2:2123', () {
      expect(
        normalizeCompozyBaseUrl('http://localhost:2123', isAndroid: true),
        equals('http://10.0.2.2:2123'),
      );
    });

    test('http://127.0.0.1:9999/api + isAndroid keeps port and path', () {
      expect(
        normalizeCompozyBaseUrl('http://127.0.0.1:9999/api', isAndroid: true),
        equals('http://10.0.2.2:9999/api'),
      );
    });

    test('IPv6 loopback + isAndroid -> http://10.0.2.2:2123/api', () {
      expect(
        normalizeCompozyBaseUrl('http://[::1]:2123/api', isAndroid: true),
        equals('http://10.0.2.2:2123/api'),
      );
    });

    test('http://192.168.0.10:2123 untouched', () {
      expect(
        normalizeCompozyBaseUrl('http://192.168.0.10:2123', isAndroid: true),
        equals('http://192.168.0.10:2123'),
      );
      expect(
        normalizeCompozyBaseUrl('http://192.168.0.10:2123', isAndroid: false),
        equals('http://192.168.0.10:2123'),
      );
    });

    test('http://localhost:2123 with isAndroid: false untouched', () {
      expect(
        normalizeCompozyBaseUrl('http://localhost:2123', isAndroid: false),
        equals('http://localhost:2123'),
      );
    });

    test('trailing slash trimmed', () {
      expect(
        normalizeCompozyBaseUrl('http://localhost:2123/', isAndroid: true),
        equals('http://10.0.2.2:2123'),
      );
      expect(
        normalizeCompozyBaseUrl('http://192.168.0.10:2123/', isAndroid: true),
        equals('http://192.168.0.10:2123'),
      );
      expect(
        normalizeCompozyBaseUrl('http://127.0.0.1:9999/api/', isAndroid: true),
        equals('http://10.0.2.2:9999/api'),
      );
      expect(
        normalizeCompozyBaseUrl('http://localhost:2123///', isAndroid: false),
        equals('http://localhost:2123'),
      );
    });

    test('CompozyApiClient normalizes baseUrl on construction and updateSettings', () {
      final client = CompozyApiClient(
        baseUrl: 'http://localhost:2123',
        isAndroid: true,
      );
      expect(client.baseUrl, equals('http://10.0.2.2:2123'));

      client.updateSettings(const Settings(baseUrl: 'http://192.168.1.1:2123/'));
      expect(client.baseUrl, equals('http://192.168.1.1:2123'));
    });
  });
}
