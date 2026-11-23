import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_exceptions.dart';

/// Riverpod provider for [CompozyApiClient].
final compozyApiClientProvider = Provider<CompozyApiClient>((ref) {
  return CompozyApiClient();
});

/// Abstract client for communicating with the CompozyOS daemon REST API.
abstract class CompozyApiClient {
  /// Default factory constructor creating [CompozyApiClientImpl].
  factory CompozyApiClient({
    Dio? dio,
    String baseUrl,
    String? appToken,
  }) = CompozyApiClientImpl;

  /// The active base URL for requests.
  String get baseUrl;

  /// Performs a GET request to the given [path].
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  });

  /// Performs a POST request to the given [path].
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  });
}

/// Default implementation of [CompozyApiClient] using [Dio].
class CompozyApiClientImpl implements CompozyApiClient {
  final Dio _dio;

  @override
  final String baseUrl;

  final String? appToken;

  CompozyApiClientImpl({
    Dio? dio,
    this.baseUrl = 'http://localhost:2123',
    this.appToken,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Accept': 'application/json',
                  if (appToken != null && appToken.isNotEmpty)
                    'Authorization': 'Bearer $appToken',
                },
              ),
            ) {
    if (dio != null) {
      if (_dio.options.baseUrl.isEmpty) {
        _dio.options.baseUrl = baseUrl;
      }
      _dio.options.connectTimeout ??= const Duration(seconds: 5);
      _dio.options.receiveTimeout ??= const Duration(seconds: 10);
      _dio.options.headers.putIfAbsent('Accept', () => 'application/json');
      if (appToken != null && appToken!.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $appToken';
      }
    }
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw CompozyApiException.fromDioException(e);
    } catch (e) {
      if (e is CompozyApiException) rethrow;
      throw CompozyApiException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _normalizeResponse(response.data);
    } on DioException catch (e) {
      throw CompozyApiException.fromDioException(e);
    } catch (e) {
      if (e is CompozyApiException) rethrow;
      throw CompozyApiException(message: e.toString());
    }
  }

  Map<String, dynamic> _normalizeResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data == null) {
      return <String, dynamic>{};
    } else {
      return <String, dynamic>{'data': data};
    }
  }
}
