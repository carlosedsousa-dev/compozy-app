import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/core/network/health_checker.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      '{"status": "ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompozyApiClient Settings Integration (UT-016)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('testApiClientDynamicBaseUrl - dynamically updates Dio baseUrl when settings change', () async {
      SharedPreferences.setMockInitialValues({
        'compozy_base_url': 'http://localhost:2123',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(compozyApiClientProvider);
      expect(client.baseUrl, equals('http://localhost:2123'));
      expect(client.dio.options.baseUrl, equals('http://localhost:2123'));

      // Update baseUrl via settings notifier
      await container
          .read(settingsProvider.notifier)
          .updateBaseUrl('http://192.168.1.200:2123');

      // Verify client.baseUrl and client.dio.options.baseUrl are dynamically updated
      expect(client.baseUrl, equals('http://192.168.1.200:2123'));
      expect(client.dio.options.baseUrl, equals('http://192.168.1.200:2123'));

      // Update API token via settings notifier
      await container
          .read(settingsProvider.notifier)
          .updateApiToken('token_new_auth_123');

      expect(client.appToken, equals('token_new_auth_123'));
      expect(
        client.dio.options.headers['Authorization'],
        equals('Bearer token_new_auth_123'),
      );

      // Clear API token via settings notifier
      await container.read(settingsProvider.notifier).updateApiToken(null);
      expect(client.appToken, isNull);
      expect(client.dio.options.headers.containsKey('Authorization'), isFalse);
    });

    test('dynamically updates configuration directly on CompozyApiClient instance', () {
      final client = CompozyApiClient(baseUrl: 'http://localhost:2123');
      expect(client.baseUrl, equals('http://localhost:2123'));
      expect(client.dio.options.baseUrl, equals('http://localhost:2123'));

      client.updateBaseUrl('http://remote-node:2123');
      expect(client.baseUrl, equals('http://remote-node:2123'));
      expect(client.dio.options.baseUrl, equals('http://remote-node:2123'));

      client.updateAppToken('token-direct-456');
      expect(client.appToken, equals('token-direct-456'));
      expect(
        client.dio.options.headers['Authorization'],
        equals('Bearer token-direct-456'),
      );

      client.updateSettings(const Settings(
        baseUrl: 'http://custom-cluster:8080',
        apiToken: 'cluster-token',
      ));
      expect(client.baseUrl, equals('http://custom-cluster:8080'));
      expect(client.dio.options.baseUrl, equals('http://custom-cluster:8080'));
      expect(client.appToken, equals('cluster-token'));
      expect(
        client.dio.options.headers['Authorization'],
        equals('Bearer cluster-token'),
      );
    });

    test('dispatches HTTP request with dynamically updated Base URL and Authorization header', () async {
      final mockAdapter = _CapturingHttpClientAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = mockAdapter;

      final client = CompozyApiClient(dio: dio);
      await client.get('/api/test');
      expect(mockAdapter.lastRequestOptions?.baseUrl, equals('http://localhost:2123'));
      expect(mockAdapter.lastRequestOptions?.headers.containsKey('Authorization'), isFalse);

      // Dynamically update baseUrl and token
      client.updateConfiguration(
        baseUrl: 'http://10.0.0.50:2123',
        appToken: 'bearer-test-token',
      );

      await client.get('/api/test');
      expect(mockAdapter.lastRequestOptions?.baseUrl, equals('http://10.0.0.50:2123'));
      expect(
        mockAdapter.lastRequestOptions?.headers['Authorization'],
        equals('Bearer bearer-test-token'),
      );
    });

    test('healthCheckerProvider reflects dynamically updated baseUrl from settings', () async {
      SharedPreferences.setMockInitialValues({
        'compozy_base_url': 'http://localhost:2123',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final healthChecker = container.read(healthCheckerProvider);
      expect(healthChecker.baseUrl, equals('http://localhost:2123'));

      await container
          .read(settingsProvider.notifier)
          .updateBaseUrl('http://192.168.1.55:2123');

      final updatedHealthChecker = container.read(healthCheckerProvider);
      expect(updatedHealthChecker.baseUrl, equals('http://192.168.1.55:2123'));
    });
  });
}
