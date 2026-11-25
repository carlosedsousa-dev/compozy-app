import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';
import '../settings/settings_repository.dart';
import 'api_exceptions.dart';

/// Returns the default base URL for CompozyOS daemon.
/// Uses 10.0.2.2 when running on Android emulator/device to reach host loopback.
String defaultCompozyBaseUrl({bool? isAndroid}) {
  final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
  if (android) {
    return 'http://10.0.2.2:2123';
  }
  return 'http://localhost:2123';
}

/// Resolves a user-supplied base URL into one usable from this platform.
/// - null/blank -> the platform default
/// - on Android, a loopback host (localhost, 127.0.0.1, [::1]) -> 10.0.2.2, keeping port and path
/// - every other value is preserved verbatim (aside from trim + trailing-slash removal)
String normalizeCompozyBaseUrl(String? raw, {bool? isAndroid}) {
  final android = isAndroid ?? (!kIsWeb && Platform.isAndroid);
  if (raw == null || raw.trim().isEmpty) {
    return defaultCompozyBaseUrl(isAndroid: android);
  }

  var trimmed = raw.trim();
  trimmed = trimmed.replaceAll(RegExp(r'/+$'), '');

  if (android) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasAuthority) {
      final rawHost = uri.host.toLowerCase();
      final cleanHost = (rawHost.startsWith('[') && rawHost.endsWith(']'))
          ? rawHost.substring(1, rawHost.length - 1)
          : rawHost;
      if (cleanHost == 'localhost' ||
          cleanHost == '127.0.0.1' ||
          cleanHost == '::1') {
        final replaced = uri.replace(host: '10.0.2.2').toString();
        return replaced.replaceAll(RegExp(r'/+$'), '');
      }
    }
  }

  return trimmed;
}

/// Riverpod provider for [CompozyApiClient].
/// Dynamically updates configuration whenever [settingsProvider] changes.
final compozyApiClientProvider = Provider<CompozyApiClient>((ref) {
  final initialSettings = ref.read(settingsProvider);
  final client = CompozyApiClient(
    baseUrl: initialSettings.baseUrl,
    appToken: initialSettings.apiToken,
  );

  ref.listen<Settings>(settingsProvider, (previous, next) {
    client.updateSettings(next);
  });

  return client;
});

/// Abstract client for communicating with the CompozyOS daemon REST API.
abstract class CompozyApiClient {
  /// Default factory constructor creating [CompozyApiClientImpl].
  factory CompozyApiClient({
    Dio? dio,
    String? baseUrl,
    String? appToken,
    Settings? settings,
    bool? isAndroid,
  }) {
    return CompozyApiClientImpl(
      dio: dio,
      baseUrl: baseUrl ?? settings?.baseUrl,
      appToken: appToken ?? settings?.apiToken,
      isAndroid: isAndroid,
    );
  }

  /// The active base URL for requests.
  String get baseUrl;

  /// The active app/API token for requests, if any.
  String? get appToken;

  /// The underlying [Dio] instance.
  Dio get dio;

  /// Updates the Base URL dynamically on this client and its underlying HTTP client.
  void updateBaseUrl(String newBaseUrl);

  /// Updates the app token dynamically on this client and its underlying HTTP client headers.
  void updateAppToken(String? newAppToken);

  /// Updates configuration dynamically from parameters.
  void updateConfiguration({String? baseUrl, String? appToken});

  /// Updates configuration directly from [Settings].
  void updateSettings(Settings settings);

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
  String _baseUrl;
  String? _appToken;

  @override
  Dio get dio => _dio;

  @override
  String get baseUrl =>
      _dio.options.baseUrl.isNotEmpty ? _dio.options.baseUrl : _baseUrl;

  @override
  String? get appToken => _appToken;

  CompozyApiClientImpl({
    Dio? dio,
    String? baseUrl,
    String? appToken,
    bool? isAndroid,
  })  : _baseUrl = normalizeCompozyBaseUrl(baseUrl, isAndroid: isAndroid),
        _appToken = appToken,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: normalizeCompozyBaseUrl(baseUrl, isAndroid: isAndroid),
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
        _dio.options.baseUrl = _baseUrl;
      } else {
        _dio.options.baseUrl =
            normalizeCompozyBaseUrl(_dio.options.baseUrl, isAndroid: isAndroid);
        _baseUrl = _dio.options.baseUrl;
      }
      _dio.options.connectTimeout ??= const Duration(seconds: 5);
      _dio.options.receiveTimeout ??= const Duration(seconds: 10);
      _dio.options.headers.putIfAbsent('Accept', () => 'application/json');
      if (appToken != null && appToken.isNotEmpty) {
        _dio.options.headers['Authorization'] = 'Bearer $appToken';
      }
    }
  }

  @override
  void updateBaseUrl(String newBaseUrl) {
    final normalized = normalizeCompozyBaseUrl(newBaseUrl);
    _baseUrl = normalized;
    _dio.options.baseUrl = normalized;
  }

  @override
  void updateAppToken(String? newAppToken) {
    _appToken = newAppToken;
    if (newAppToken != null && newAppToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $newAppToken';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  @override
  void updateConfiguration({String? baseUrl, String? appToken}) {
    if (baseUrl != null) {
      updateBaseUrl(baseUrl);
    }
    if (appToken != null || (baseUrl != null && appToken == null)) {
      updateAppToken(appToken);
    }
  }

  @override
  void updateSettings(Settings settings) {
    updateConfiguration(
      baseUrl: normalizeCompozyBaseUrl(settings.baseUrl),
      appToken: settings.apiToken,
    );
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
