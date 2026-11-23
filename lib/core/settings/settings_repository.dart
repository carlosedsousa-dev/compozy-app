import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Provider for the [SharedPreferences] instance.
/// Can be overridden in tests or initialization.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Provider for [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(preferences: prefs);
});

/// Reactive [StateNotifier] managing application [Settings].
class SettingsNotifier extends StateNotifier<Settings> {
  final SettingsRepository _repository;
  bool _userModified = false;

  SettingsNotifier(
    this._repository, [
    Settings? initialSettings,
  ]) : super(_repository.cachedSettings ?? initialSettings ?? const Settings()) {
    if (_repository.cachedSettings == null) {
      _init();
    }
  }

  Future<void> _init() async {
    try {
      final loaded = await _repository.loadSettings();
      if (!_userModified) {
        state = loaded;
      }
    } catch (_) {
      // In isolated pure-Dart test environments where SharedPreferences isn't mocked,
      // fail safely and preserve initial state.
    }
  }

  /// Updates and persists the full [Settings] state.
  Future<void> updateSettings(Settings newSettings) async {
    _userModified = true;
    state = newSettings;
    await _repository.saveSettings(newSettings);
  }

  /// Updates and persists the Base URL.
  Future<void> updateBaseUrl(String baseUrl) async {
    _userModified = true;
    final updated = state.copyWith(baseUrl: baseUrl);
    state = updated;
    await _repository.saveSettings(updated);
  }

  /// Updates and persists the API token.
  Future<void> updateApiToken(String? apiToken) async {
    _userModified = true;
    final updated = state.copyWith(
      apiToken: apiToken,
      clearApiToken: apiToken == null || apiToken.isEmpty,
    );
    state = updated;
    await _repository.saveSettings(updated);
  }

  /// Updates and persists the active workspace identifier.
  Future<void> updateActiveWorkspaceId(String? workspaceId) async {
    _userModified = true;
    final updated = state.copyWith(
      activeWorkspaceId: workspaceId,
      clearActiveWorkspaceId: workspaceId == null || workspaceId.isEmpty,
    );
    state = updated;
    await _repository.saveSettings(updated);
  }

  /// Updates and persists the theme mode.
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    _userModified = true;
    final updated = state.copyWith(themeMode: themeMode);
    state = updated;
    await _repository.saveSettings(updated);
  }
}

/// Riverpod provider for reactive [Settings] access and updates.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repository);
});

/// Alias provider for [settingsProvider].
final settingsNotifierProvider = settingsProvider;

/// Repository interface for persisting and loading application settings.
abstract class SettingsRepository {
  /// Factory constructor returning standard [SettingsRepositoryImpl].
  factory SettingsRepository({
    SharedPreferences? preferences,
    SharedPreferences? prefs,
  }) = SettingsRepositoryImpl;

  /// Loads persisted settings from storage or returns defaults.
  Future<Settings> loadSettings();

  /// Retrieves current settings (alias for [loadSettings]).
  Future<Settings> getSettings();

  /// Persists the given [Settings] to storage.
  Future<void> saveSettings(Settings settings);

  /// Updates the given [Settings] in storage (alias for [saveSettings]).
  Future<void> updateSettings(Settings settings);

  /// Currently cached [Settings], if loaded.
  Settings? get cachedSettings;
}

/// Implementation of [SettingsRepository] backed by [SharedPreferences].
class SettingsRepositoryImpl implements SettingsRepository {
  SharedPreferences? _preferences;
  Settings? _cachedSettings;

  SettingsRepositoryImpl({
    SharedPreferences? preferences,
    SharedPreferences? prefs,
  }) : _preferences = preferences ?? prefs {
    if (_preferences != null) {
      _cachedSettings = _readFromPrefs(_preferences!);
    }
  }

  @override
  Settings? get cachedSettings => _cachedSettings;

  Future<SharedPreferences> _getPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  static const String _keyBaseUrl = 'compozy_base_url';
  static const String _keyApiToken = 'compozy_api_token';
  static const String _keyActiveWorkspaceId = 'compozy_active_workspace_id';
  static const String _keyThemeMode = 'compozy_theme_mode';

  Settings _readFromPrefs(SharedPreferences prefs) {
    final baseUrl = prefs.getString(_keyBaseUrl) ??
        prefs.getString('baseUrl') ??
        prefs.getString('base_url') ??
        'http://localhost:2123';

    final apiToken = prefs.getString(_keyApiToken) ??
        prefs.getString('apiToken') ??
        prefs.getString('api_token');

    final activeWorkspaceId = prefs.getString(_keyActiveWorkspaceId) ??
        prefs.getString('activeWorkspaceId') ??
        prefs.getString('active_workspace_id');

    final themeStr = prefs.getString(_keyThemeMode) ??
        prefs.getString('themeMode') ??
        prefs.getString('theme_mode');

    ThemeMode themeMode = ThemeMode.dark;
    if (themeStr != null) {
      final lower = themeStr.toLowerCase();
      if (lower == 'light' || lower == 'thememode.light') {
        themeMode = ThemeMode.light;
      } else if (lower == 'system' || lower == 'thememode.system') {
        themeMode = ThemeMode.system;
      } else {
        themeMode = ThemeMode.dark;
      }
    }

    return Settings(
      baseUrl: baseUrl,
      apiToken: apiToken?.isNotEmpty == true ? apiToken : null,
      activeWorkspaceId:
          activeWorkspaceId?.isNotEmpty == true ? activeWorkspaceId : null,
      themeMode: themeMode,
    );
  }

  @override
  Future<Settings> loadSettings() async {
    try {
      final prefs = await _getPrefs();
      final loaded = _readFromPrefs(prefs);
      _cachedSettings = loaded;
      return loaded;
    } catch (_) {
      return _cachedSettings ?? const Settings();
    }
  }

  @override
  Future<Settings> getSettings() => loadSettings();

  @override
  Future<void> saveSettings(Settings settings) async {
    final prefs = await _getPrefs();

    // Store under primary and legacy/alternate keys for maximum compatibility
    await prefs.setString(_keyBaseUrl, settings.baseUrl);
    await prefs.setString('baseUrl', settings.baseUrl);
    await prefs.setString('base_url', settings.baseUrl);

    if (settings.apiToken != null && settings.apiToken!.isNotEmpty) {
      await prefs.setString(_keyApiToken, settings.apiToken!);
      await prefs.setString('apiToken', settings.apiToken!);
      await prefs.setString('api_token', settings.apiToken!);
    } else {
      await prefs.remove(_keyApiToken);
      await prefs.remove('apiToken');
      await prefs.remove('api_token');
    }

    if (settings.activeWorkspaceId != null &&
        settings.activeWorkspaceId!.isNotEmpty) {
      await prefs.setString(_keyActiveWorkspaceId, settings.activeWorkspaceId!);
      await prefs.setString('activeWorkspaceId', settings.activeWorkspaceId!);
      await prefs.setString('active_workspace_id', settings.activeWorkspaceId!);
    } else {
      await prefs.remove(_keyActiveWorkspaceId);
      await prefs.remove('activeWorkspaceId');
      await prefs.remove('active_workspace_id');
    }

    await prefs.setString(_keyThemeMode, settings.themeMode.name);
    await prefs.setString('themeMode', settings.themeMode.name);
    await prefs.setString('theme_mode', settings.themeMode.name);

    _cachedSettings = settings;
  }

  @override
  Future<void> updateSettings(Settings settings) => saveSettings(settings);
}
