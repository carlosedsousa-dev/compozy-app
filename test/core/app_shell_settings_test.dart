import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/presentation/app_shell.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/settings/presentation/settings_screen.dart';

class _MockSettingsRepository implements SettingsRepository {
  Settings _settings = const Settings();

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
  group('testAppShellSettingsTab (WT-004)', () {
    testWidgets('renders Settings tab on mobile BottomNavigationBar and navigates to SettingsScreen', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(const [])),
            loopsProvider.overrideWith((ref) => Future.value(const [])),
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: AppNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mobile BottomNavigationBar is present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      // Verify Settings item in BottomNavigationBar
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify SettingsScreen is rendered
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Daemon Settings'), findsOneWidget);
      expect(find.byKey(const Key('settings_base_url_field')), findsOneWidget);
      expect(find.byKey(const Key('settings_test_connection_button')), findsOneWidget);
      expect(find.byKey(const Key('settings_save_button')), findsOneWidget);
    });

    testWidgets('renders Settings destination on desktop NavigationRail and navigates to SettingsScreen', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(const [])),
            loopsProvider.overrideWith((ref) => Future.value(const [])),
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: AppNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Desktop NavigationRail is present
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);

      // Verify Settings rail destination
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Tap Settings rail destination icon
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Verify SettingsScreen is rendered on wide screen
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Daemon Settings'), findsOneWidget);
      expect(find.byKey(const Key('settings_screen')), findsOneWidget);
    });

    testWidgets('switches between Sessions, Loops, and Settings tabs cleanly', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(const [])),
            loopsProvider.overrideWith((ref) => Future.value(const [])),
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: AppNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start on Sessions (index 0)
      expect(find.text('No sessions found'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      // Switch to Loops (index 1)
      await tester.tap(find.text('Loops'));
      await tester.pumpAndSettle();
      expect(find.text('Loops Catalog'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      // Switch to Settings (index 2)
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Daemon Settings'), findsOneWidget);

      // Switch back to Sessions (index 0)
      await tester.tap(find.text('Sessions'));
      await tester.pumpAndSettle();
      expect(find.text('No sessions found'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });
}
