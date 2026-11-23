import 'dart:typed_data';

import 'package:compozy_app/core/network/health_checker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final int statusCode;
  final bool shouldThrow;

  _MockHttpClientAdapter({
    required this.statusCode,
    this.shouldThrow = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (shouldThrow) {
      throw DioException(
        requestOptions: options,
        error: 'Connection refused',
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      '{"openapi": "3.0.0"}',
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
  group('HealthChecker', () {
    test('testHealthSuccess - returns true when daemon returns 200 on /api/openapi.json', () async {
      // Arrange
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(statusCode: 200);
      final healthChecker = HealthChecker(dio: dio);

      // Act
      final result = await healthChecker.checkHealth();

      // Assert
      expect(result, isTrue);
    });

    test('returns false when daemon returns non-200', () async {
      // Arrange
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(statusCode: 500);
      final healthChecker = HealthChecker(dio: dio);

      // Act
      final result = await healthChecker.checkHealth();

      // Assert
      expect(result, isFalse);
    });

    test('returns false when network request fails', () async {
      // Arrange
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(statusCode: 0, shouldThrow: true);
      final healthChecker = HealthChecker(dio: dio);

      // Act
      final result = await healthChecker.checkHealth();

      // Assert
      expect(result, isFalse);
    });
  });
}
