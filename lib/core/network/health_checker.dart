import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_repository.dart';
import 'api_exceptions.dart';
import 'compozy_api_client.dart';

final healthCheckerProvider = Provider<HealthChecker>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  final settings = ref.watch(settingsProvider);
  return HealthChecker(apiClient: apiClient, baseUrl: settings.baseUrl);
});

/// Client for checking connectivity and reachability of the CompozyOS daemon.
class HealthChecker {
  final CompozyApiClient? apiClient;
  final Dio _dio;
  final String _baseUrl;
  final bool? isAndroid;

  /// The active base URL being checked.
  String get baseUrl => apiClient?.baseUrl ?? _baseUrl;

  HealthChecker({
    this.apiClient,
    Dio? dio,
    String? baseUrl,
    this.isAndroid,
  })  : _baseUrl = normalizeCompozyBaseUrl(
          baseUrl ??
              (dio != null && dio.options.baseUrl.isNotEmpty
                  ? dio.options.baseUrl
                  : null) ??
              apiClient?.baseUrl,
          isAndroid: isAndroid,
        ),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: normalizeCompozyBaseUrl(
                  baseUrl ?? apiClient?.baseUrl,
                  isAndroid: isAndroid,
                ),
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ) {
    if (dio != null) {
      if (_dio.options.baseUrl.isEmpty) {
        _dio.options.baseUrl = _baseUrl;
      } else {
        _dio.options.baseUrl =
            normalizeCompozyBaseUrl(_dio.options.baseUrl, isAndroid: isAndroid);
      }
    }
  }

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
