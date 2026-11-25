import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository (UT-015)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('testSettingsPersistence - saves and loads Base URL, token, and active workspace across restarts', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      // 1. Initial default state (US-005.AC-1)
      final initialSettings = await repository.loadSettings();
      expect(initialSettings.baseUrl, equals('http://localhost:2123'));
      expect(initialSettings.apiToken, isNull);
      expect(initialSettings.activeWorkspaceId, isNull);
      expect(initialSettings.themeMode, equals(ThemeMode.dark));

      // 2. Save custom settings
      const newSettings = Settings(
        baseUrl: 'http://192.168.1.150:2123',
        apiToken: 'token_secret_xyz_987',
        activeWorkspaceId: 'ws_custom_workspace',
        themeMode: ThemeMode.light,
      );
      await repository.saveSettings(newSettings);

      // 3. Simulate app restart by instantiating a new repository with the same SharedPreferences (US-005.AC-2)
      final restartedRepository = SettingsRepository(preferences: prefs);
      final loadedSettings = await restartedRepository.loadSettings();

      expect(loadedSettings.baseUrl, equals('http://192.168.1.150:2123'));
      expect(loadedSettings.apiToken, equals('token_secret_xyz_987'));
      expect(loadedSettings.activeWorkspaceId, equals('ws_custom_workspace'));
      expect(loadedSettings.themeMode, equals(ThemeMode.light));
      expect(loadedSettings, equals(newSettings));
    });

    test('persists clearing token and active workspace', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      await repository.saveSettings(const Settings(
        baseUrl: 'http://localhost:2123',
        apiToken: 'temp_token',
        activeWorkspaceId: 'ws_temp',
        themeMode: ThemeMode.dark,
      ));

      var loaded = await repository.loadSettings();
      expect(loaded.apiToken, equals('temp_token'));
      expect(loaded.activeWorkspaceId, equals('ws_temp'));

      // Clear token and active workspace
      await repository.saveSettings(loaded.copyWith(
        clearApiToken: true,
        clearActiveWorkspaceId: true,
      ));

      final restartedRepo = SettingsRepository(preferences: prefs);
      loaded = await restartedRepo.loadSettings();
      expect(loaded.apiToken, isNull);
      expect(loaded.activeWorkspaceId, isNull);
    });

    test('loads from alternate/legacy snake_case keys in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'base_url': 'http://remote.daemon:2123',
        'api_token': 'snake_token',
        'active_workspace_id': 'ws_snake_id',
        'theme_mode': 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      final settings = await repository.loadSettings();
      expect(settings.baseUrl, equals('http://remote.daemon:2123'));
      expect(settings.apiToken, equals('snake_token'));
      expect(settings.activeWorkspaceId, equals('ws_snake_id'));
      expect(settings.themeMode, equals(ThemeMode.light));
    });

    test('Settings domain model serialization and copyWith', () {
      const settings = Settings(
        baseUrl: 'http://localhost:2123',
        apiToken: 'test_token',
        activeWorkspaceId: 'ws_abc',
        themeMode: ThemeMode.system,
      );

      final map = settings.toMap();
      expect(map['baseUrl'], equals('http://localhost:2123'));
      expect(map['apiToken'], equals('test_token'));
      expect(map['activeWorkspaceId'], equals('ws_abc'));
      expect(map['themeMode'], equals('system'));

      final fromMap = Settings.fromMap(map);
      expect(fromMap, equals(settings));
      expect(fromMap.hashCode, equals(settings.hashCode));

      final json = settings.toJson();
      final fromJson = Settings.fromJson(json);
      expect(fromJson, equals(settings));

      final copied = settings.copyWith(
        baseUrl: 'http://new-url:2123',
        themeMode: ThemeMode.dark,
      );
      expect(copied.baseUrl, equals('http://new-url:2123'));
      expect(copied.apiToken, equals('test_token'));
      expect(copied.themeMode, equals(ThemeMode.dark));

      expect(settings.toString(), contains('http://localhost:2123'));
      expect(settings.toString(), contains('***')); // masked token in toString
    });

    test('SettingsNotifier updates state and saves to repository', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);
      final notifier = SettingsNotifier(repository);

      await notifier.updateBaseUrl('http://notifier-test:2123');
      expect(notifier.state.baseUrl, equals('http://notifier-test:2123'));

      await notifier.updateApiToken('token-notifier');
      expect(notifier.state.apiToken, equals('token-notifier'));

      await notifier.updateActiveWorkspaceId('ws-notifier');
      expect(notifier.state.activeWorkspaceId, equals('ws-notifier'));

      await notifier.updateThemeMode(ThemeMode.light);
      expect(notifier.state.themeMode, equals(ThemeMode.light));

      final loaded = await repository.loadSettings();
      expect(loaded.baseUrl, equals('http://notifier-test:2123'));
      expect(loaded.apiToken, equals('token-notifier'));
      expect(loaded.activeWorkspaceId, equals('ws-notifier'));
      expect(loaded.themeMode, equals(ThemeMode.light));
    });

    test('empty prefs on Android yields 10.0.2.2', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs, isAndroid: true);

      final settings = await repository.loadSettings();
      expect(settings.baseUrl, equals('http://10.0.2.2:2123'));
    });

    test('persisted legacy localhost literal is migrated on Android', () async {
      SharedPreferences.setMockInitialValues({
        'compozy_base_url': 'http://localhost:2123',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs, isAndroid: true);

      final settings = await repository.loadSettings();
      expect(settings.baseUrl, equals('http://10.0.2.2:2123'));
      expect(prefs.getString('compozy_base_url'), equals('http://10.0.2.2:2123'));
    });

    test('persisted custom URL is preserved on Android', () async {
      SharedPreferences.setMockInitialValues({
        'compozy_base_url': 'http://192.168.1.88:2123',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs, isAndroid: true);

      final settings = await repository.loadSettings();
      expect(settings.baseUrl, equals('http://192.168.1.88:2123'));
    });

    test('hasConfirmedConnection defaults to false and round-trips via setConfirmedConnection', () async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      // Default is false
      final initial = await repository.loadSettings();
      expect(initial.hasConfirmedConnection, isFalse);

      // Set confirmed connection via repository method
      await repository.setConfirmedConnection(true);

      // Reload from storage
      final updated = await repository.loadSettings();
      expect(updated.hasConfirmedConnection, isTrue);

      // Verify persistence across new repository instance
      final restartedRepo = SettingsRepository(preferences: prefs);
      final persisted = await restartedRepo.loadSettings();
      expect(persisted.hasConfirmedConnection, isTrue);

      // Set back to false
      await repository.setConfirmedConnection(false);
      final reset = await restartedRepo.loadSettings();
      expect(reset.hasConfirmedConnection, isFalse);
    });

    test('Settings domain model hasConfirmedConnection default and serialization', () {
      // Default constructor value is false
      const defaultSettings = Settings();
      expect(defaultSettings.hasConfirmedConnection, isFalse);

      // Serialization round-trip with true
      const confirmedSettings = Settings(hasConfirmedConnection: true);
      final map = confirmedSettings.toMap();
      expect(map['hasConfirmedConnection'], isTrue);

      final fromMap = Settings.fromMap(map);
      expect(fromMap.hasConfirmedConnection, isTrue);

      // Absent key in JSON/map defaults to false
      final absentMap = <String, dynamic>{'baseUrl': 'http://custom:2123'};
      final fromAbsent = Settings.fromMap(absentMap);
      expect(fromAbsent.hasConfirmedConnection, isFalse);
    });
  });
}
