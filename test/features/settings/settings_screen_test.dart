import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/network/health_checker.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/settings/presentation/settings_screen.dart';

class _FakeHealthChecker extends HealthChecker {
  final bool healthy;

  _FakeHealthChecker({required this.healthy}) : super(baseUrl: 'http://localhost:2123');

  @override
  Future<bool> checkHealth() async => healthy;
}

class _InMemorySettingsRepository implements SettingsRepository {
  Settings _settings;

  _InMemorySettingsRepository([Settings? initial])
      : _settings = initial ?? const Settings();

  @override
  Settings? get cachedSettings => _settings;

  @override
  Future<Settings> loadSettings() async => _settings;

  @override
  Future<Settings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(Settings settings) async {
    _settings = settings;
  }

  @override
  Future<void> updateSettings(Settings settings) async {
    _settings = settings;
  }
}

void main() {
  group('testSettingsScreen (IT-005)', () {
    testWidgets('renders input fields with initial settings and action buttons', (tester) async {
      final repo = _InMemorySettingsRepository(
        const Settings(
          baseUrl: 'http://localhost:2123',
          apiToken: 'initial-token',
          activeWorkspaceId: 'ws-main',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Daemon Settings'), findsOneWidget);
      expect(find.text('REST API'), findsOneWidget);

      // Input fields
      expect(find.byKey(const Key('settings_base_url_field')), findsOneWidget);
      expect(find.byKey(const Key('settings_api_token_field')), findsOneWidget);
      expect(find.byKey(const Key('settings_workspace_field')), findsOneWidget);

      // Verify prefilled values
      expect(find.text('http://localhost:2123'), findsOneWidget);
      expect(find.text('initial-token'), findsOneWidget);
      expect(find.text('ws-main'), findsOneWidget);

      // Action buttons
      expect(find.byKey(const Key('settings_test_connection_button')), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.byKey(const Key('settings_save_button')), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.byKey(const Key('settings_reset_button')), findsOneWidget);
      expect(find.text('Reset Defaults'), findsOneWidget);
    });

    testWidgets('toggles API token visibility when visibility icon is pressed', (tester) async {
      final repo = _InMemorySettingsRepository(
        const Settings(apiToken: 'secret-auth-token'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially obscureText is true (Icon: visibility_off)
      final tokenFieldFinder = find.byKey(const Key('settings_api_token_field'));
      expect(tokenFieldFinder, findsOneWidget);
      final editableTextInitial = tester.widget<EditableText>(
        find.descendant(of: tokenFieldFinder, matching: find.byType(EditableText)),
      );
      expect(editableTextInitial.obscureText, isTrue);

      // Tap toggle visibility button
      await tester.tap(find.byKey(const Key('settings_toggle_token_visibility')));
      await tester.pumpAndSettle();

      final editableTextRevealed = tester.widget<EditableText>(
        find.descendant(of: tokenFieldFinder, matching: find.byType(EditableText)),
      );
      expect(editableTextRevealed.obscureText, isFalse);
    });

    testWidgets('tests connection successfully and displays success feedback banner', (tester) async {
      final repo = _InMemorySettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            healthCheckerProvider.overrideWithValue(_FakeHealthChecker(healthy: true)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Test Connection
      await tester.tap(find.byKey(const Key('settings_test_connection_button')));
      await tester.pumpAndSettle();

      // Verify success feedback banner
      expect(find.byKey(const Key('connection_test_success_banner')), findsOneWidget);
      expect(find.text('Daemon is reachable (HTTP 200 OK)'), findsOneWidget);
    });

    testWidgets('tests connection failure and displays error feedback banner', (tester) async {
      final repo = _InMemorySettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            healthCheckerProvider.overrideWithValue(_FakeHealthChecker(healthy: false)),
            connectionStatusProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Test Connection
      await tester.tap(find.byKey(const Key('settings_test_connection_button')));
      await tester.pumpAndSettle();

      // Verify error feedback banner
      expect(find.byKey(const Key('connection_test_error_banner')), findsOneWidget);
      expect(find.text('Connection failed: unable to reach daemon'), findsOneWidget);
    });

    testWidgets('saves updated settings and displays snackbar notification', (tester) async {
      final repo = _InMemorySettingsRepository();
      late SettingsNotifier notifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) {
              notifier = SettingsNotifier(repo);
              return notifier;
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter new Base URL
      final baseUrlField = find.byKey(const Key('settings_base_url_field'));
      await tester.enterText(baseUrlField, 'http://192.168.1.100:2123');

      // Enter new API Token
      final tokenField = find.byKey(const Key('settings_api_token_field'));
      await tester.enterText(tokenField, 'secure_bearer_token_999');

      // Enter new Workspace
      final workspaceField = find.byKey(const Key('settings_workspace_field'));
      await tester.enterText(workspaceField, 'ws_production_backend');

      await tester.pump();

      // Tap Save Changes
      final saveButtonFinder = find.byKey(const Key('settings_save_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify state was saved to provider
      expect(notifier.state.baseUrl, 'http://192.168.1.100:2123');
      expect(notifier.state.apiToken, 'secure_bearer_token_999');
      expect(notifier.state.activeWorkspaceId, 'ws_production_backend');

      // Verify snackbar is displayed
      expect(find.byKey(const Key('settings_saved_snackbar')), findsOneWidget);
      expect(find.text('Settings saved successfully'), findsOneWidget);
    });

    testWidgets('resets settings to defaults when Reset Defaults is tapped', (tester) async {
      final repo = _InMemorySettingsRepository(
        const Settings(
          baseUrl: 'http://custom-host:9999',
          apiToken: 'custom-token',
          activeWorkspaceId: 'custom-ws',
        ),
      );
      late SettingsNotifier notifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) {
              notifier = SettingsNotifier(repo);
              return notifier;
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Reset Defaults
      final resetButtonFinder = find.byKey(const Key('settings_reset_button'));
      await tester.ensureVisible(resetButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(resetButtonFinder);
      await tester.pumpAndSettle();

      // Verify defaults restored
      expect(notifier.state.baseUrl, 'http://localhost:2123');
      expect(notifier.state.apiToken, isNull);
      expect(notifier.state.activeWorkspaceId, isNull);

      // Verify text fields updated
      expect(find.text('http://localhost:2123'), findsOneWidget);
      expect(find.text('Settings reset to defaults'), findsOneWidget);
    });
  });
}
