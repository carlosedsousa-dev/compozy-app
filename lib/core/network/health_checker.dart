import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exceptions.dart';
import 'compozy_api_client.dart';

final healthCheckerProvider = Provider<HealthChecker>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  return HealthChecker(apiClient: apiClient);
});

/// Client for checking connectivity and reachability of the CompozyOS daemon.
class HealthChecker {
  final CompozyApiClient? apiClient;
  final Dio _dio;
  final String baseUrl;

  HealthChecker({
    this.apiClient,
    Dio? dio,
    this.baseUrl = 'http://localhost:2123',
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  /// Performs a health check against the CompozyOS daemon OpenAPI endpoint.
  ///
  /// Returns `true` if the daemon responds with HTTP 200, `false` otherwise.
  Future<bool> checkHealth() async {
    if (apiClient != null) {
      try {
        final response = await apiClient!.get('/api/openapi.json');
        return response.isNotEmpty;
      } on CompozyApiException {
        return false;
      } catch (_) {
        return false;
      }
    }

    try {
      final response = await _dio.get<dynamic>('/api/openapi.json');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
