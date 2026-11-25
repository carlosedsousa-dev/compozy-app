import 'package:material_ui/material_ui.dart';

/// Domain model representing application settings and daemon configuration.
class Settings {
  /// The base URL for the CompozyOS daemon REST API.
  /// Defaults to `http://localhost:2123` (or Android host loopback).
  final String baseUrl;

  /// Optional API token / App token used for daemon authentication.
  final String? apiToken;

  /// The active CompozyOS workspace identifier.
  final String? activeWorkspaceId;

  /// The selected application theme mode (dark, light, or system).
  final ThemeMode themeMode;

  /// Whether the user has explicitly confirmed the connection to the daemon.
  final bool hasConfirmedConnection;

  const Settings({
    this.baseUrl = 'http://localhost:2123',
    this.apiToken,
    this.activeWorkspaceId,
    this.themeMode = ThemeMode.dark,
    this.hasConfirmedConnection = false,
  });

  /// Creates a copy of this [Settings] instance with the given fields replaced.
  Settings copyWith({
    String? baseUrl,
    String? apiToken,
    String? activeWorkspaceId,
    ThemeMode? themeMode,
    bool? hasConfirmedConnection,
    bool clearApiToken = false,
    bool clearActiveWorkspaceId = false,
  }) {
    return Settings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiToken: clearApiToken ? null : (apiToken ?? this.apiToken),
      activeWorkspaceId: clearActiveWorkspaceId
          ? null
          : (activeWorkspaceId ?? this.activeWorkspaceId),
      themeMode: themeMode ?? this.themeMode,
      hasConfirmedConnection:
          hasConfirmedConnection ?? this.hasConfirmedConnection,
    );
  }

  /// Converts this [Settings] instance to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'baseUrl': baseUrl,
      'apiToken': apiToken,
      'activeWorkspaceId': activeWorkspaceId,
      'themeMode': themeMode.name,
      'hasConfirmedConnection': hasConfirmedConnection,
    };
  }

  /// Converts this [Settings] instance to a JSON map.
  Map<String, dynamic> toJson() => toMap();

  /// Creates a [Settings] instance from a map.
  factory Settings.fromMap(Map<String, dynamic> map) {
    ThemeMode parsedTheme = ThemeMode.dark;
    final themeRaw = map['themeMode'] ?? map['theme_mode'];
    if (themeRaw != null) {
      final themeStr = themeRaw.toString().toLowerCase();
      if (themeStr == 'light' || themeStr == 'thememode.light') {
        parsedTheme = ThemeMode.light;
      } else if (themeStr == 'system' || themeStr == 'thememode.system') {
        parsedTheme = ThemeMode.system;
      } else {
        parsedTheme = ThemeMode.dark;
      }
    }

    final rawBaseUrl = map['baseUrl'] ?? map['base_url'];
    final baseUrl = (rawBaseUrl != null && rawBaseUrl.toString().trim().isNotEmpty)
        ? rawBaseUrl.toString().trim()
        : 'http://localhost:2123';

    final apiToken = (map['apiToken'] ?? map['api_token'])?.toString();
    final activeWorkspaceId =
        (map['activeWorkspaceId'] ?? map['active_workspace_id'])?.toString();

    final rawConfirmed =
        map['hasConfirmedConnection'] ?? map['has_confirmed_connection'];
    final bool hasConfirmedConnection;
    if (rawConfirmed is bool) {
      hasConfirmedConnection = rawConfirmed;
    } else if (rawConfirmed != null) {
      hasConfirmedConnection =
          rawConfirmed.toString().toLowerCase() == 'true';
    } else {
      hasConfirmedConnection = false;
    }

    return Settings(
      baseUrl: baseUrl,
      apiToken: apiToken?.isNotEmpty == true ? apiToken : null,
      activeWorkspaceId:
          activeWorkspaceId?.isNotEmpty == true ? activeWorkspaceId : null,
      themeMode: parsedTheme,
      hasConfirmedConnection: hasConfirmedConnection,
    );
  }

  /// Creates a [Settings] instance from a JSON map.
  factory Settings.fromJson(Map<String, dynamic> json) => Settings.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          baseUrl == other.baseUrl &&
          apiToken == other.apiToken &&
          activeWorkspaceId == other.activeWorkspaceId &&
          themeMode == other.themeMode &&
          hasConfirmedConnection == other.hasConfirmedConnection;

  @override
  int get hashCode =>
      baseUrl.hashCode ^
      apiToken.hashCode ^
      activeWorkspaceId.hashCode ^
      themeMode.hashCode ^
      hasConfirmedConnection.hashCode;

  @override
  String toString() =>
      'Settings(baseUrl: $baseUrl, apiToken: ${apiToken != null ? '***' : null}, activeWorkspaceId: $activeWorkspaceId, themeMode: $themeMode, hasConfirmedConnection: $hasConfirmedConnection)';
}
