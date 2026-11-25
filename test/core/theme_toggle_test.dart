import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/presentation/app_shell.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/core/theme/theme_mode_toggle.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/settings/presentation/settings_screen.dart';
import 'package:compozy_app/main.dart';

class _InMemorySettingsRepo implements SettingsRepository {
  Settings _settings;

  _InMemorySettingsRepo([Settings? initial])
      : _settings = initial ?? const Settings(themeMode: ThemeMode.dark);

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
  group('testThemeModeToggle (WT-008)', () {
    test('CompozyTheme defines contrasting darkTheme and lightTheme token sets', () {
      final darkTheme = CompozyTheme.darkTheme;
      final lightTheme = CompozyTheme.lightTheme;

      // Brightness contracts
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(lightTheme.brightness, equals(Brightness.light));

      // Desk / Scaffold backgrounds
      expect(darkTheme.scaffoldBackgroundColor, equals(CompozyColors.desk));
      expect(lightTheme.scaffoldBackgroundColor, equals(CompozyColorsLight.desk));
      expect(lightTheme.scaffoldBackgroundColor, equals(const Color(0xFFF4F4F5)));

      // Canvas surfaces
      expect(darkTheme.canvasColor, equals(CompozyColors.canvas));
      expect(lightTheme.canvasColor, equals(CompozyColorsLight.canvas));
      expect(lightTheme.canvasColor, equals(const Color(0xFFFFFFFF)));

      // Inverted monochrome primary action
      // Dark mode: #F5F5F5 button with #0A0A0A text
      expect(darkTheme.colorScheme.primary, equals(const Color(0xFFF5F5F5)));
      expect(darkTheme.colorScheme.onPrimary, equals(const Color(0xFF0A0A0A)));

      // Light mode: #0A0A0A button with #FFFFFF text (inverted monochrome!)
      expect(lightTheme.colorScheme.primary, equals(const Color(0xFF0A0A0A)));
      expect(lightTheme.colorScheme.onPrimary, equals(const Color(0xFFFFFFFF)));

      // Lines & outlines
      expect(darkTheme.colorScheme.outline, equals(CompozyColors.line));
      expect(lightTheme.colorScheme.outline, equals(CompozyColorsLight.line));
      expect(lightTheme.colorScheme.outline, equals(const Color(0xFFE4E4E7)));
    });

    testWidgets('compact ThemeModeToggle switches theme between dark and light (US-010.AC-1)', (tester) async {
      final repo = _InMemorySettingsRepo(const Settings(themeMode: ThemeMode.dark));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: ThemeModeToggle(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('theme_mode_toggle'));
      expect(toggleFinder, findsOneWidget);

      // Initially dark mode -> icon displays light_mode to switch to light
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

      // Tap to switch to Light
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.light));
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

      // Tap again to switch back to Dark
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.dark));
      expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    });

    testWidgets('segmented ThemeModeToggle allows selecting Dark, Light, and System modes in SettingsScreen', (tester) async {
      final repo = _InMemorySettingsRepo(const Settings(themeMode: ThemeMode.dark));

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

      expect(find.byKey(const Key('settings_theme_mode_toggle')), findsOneWidget);
      expect(find.text('Appearance & Theme'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('theme_option_light')));
      await tester.pumpAndSettle();

      // Tap Light option
      await tester.tap(find.byKey(const Key('theme_option_light')));
      await tester.pumpAndSettle();
      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.light));

      // Tap System option
      await tester.tap(find.byKey(const Key('theme_option_system')));
      await tester.pumpAndSettle();
      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.system));

      // Tap Dark option
      await tester.tap(find.byKey(const Key('theme_option_dark')));
      await tester.pumpAndSettle();
      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('AppNavigationShell top bar contains theme toggle that toggles theme mode', (tester) async {
      final repo = _InMemorySettingsRepo(const Settings(themeMode: ThemeMode.dark));

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

      final shellToggleFinder = find.byKey(const Key('app_shell_theme_toggle'));
      expect(shellToggleFinder, findsOneWidget);

      // Tap shell toggle
      await tester.tap(shellToggleFinder);
      await tester.pumpAndSettle();

      expect(repo.cachedSettings!.themeMode, equals(ThemeMode.light));
    });

    testWidgets('CompozyApp reactively switches ThemeData when themeMode changes', (tester) async {
      final repo = _InMemorySettingsRepo(
        const Settings(themeMode: ThemeMode.dark, hasConfirmedConnection: true),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(const [])),
            loopsProvider.overrideWith((ref) => Future.value(const [])),
            settingsRepositoryProvider.overrideWithValue(repo),
            settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const CompozyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Initial MaterialApp ThemeData is dark
      final materialAppDark = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialAppDark.themeMode, equals(ThemeMode.dark));

      // Tap theme toggle in app shell
      await tester.tap(find.byKey(const Key('app_shell_theme_toggle')));
      await tester.pumpAndSettle();

      // MaterialApp ThemeData is now light
      final materialAppLight = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialAppLight.themeMode, equals(ThemeMode.light));
    });
  });
}
