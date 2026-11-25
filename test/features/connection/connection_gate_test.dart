import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:compozy_app/core/presentation/app_shell.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/connection/presentation/connection_gate.dart';
import 'package:compozy_app/features/connection/presentation/daemon_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConnectionGate State Matrix', () {
    testWidgets('1. Confirmed -> Shell immediately without setup or waiting', (tester) async {
      SharedPreferences.setMockInitialValues({
        'compozy_confirmed_connection': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: ConnectionGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppNavigationShell), findsOneWidget);
      expect(find.byType(DaemonSetupScreen), findsNothing);
    });

    testWidgets('2. Unconfirmed -> DaemonSetupScreen on every platform', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsRepositoryProvider.overrideWithValue(repository),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(
                repository,
                const Settings(hasConfirmedConnection: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ConnectionGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DaemonSetupScreen), findsOneWidget);
      expect(find.byType(AppNavigationShell), findsNothing);
      expect(find.text('Conectar ao daemon'), findsOneWidget);
    });

    testWidgets('3. Continue offline -> Shell without persisting confirmation', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsRepositoryProvider.overrideWithValue(repository),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(
                repository,
                const Settings(hasConfirmedConnection: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ConnectionGate(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DaemonSetupScreen), findsOneWidget);
      expect(find.byType(AppNavigationShell), findsNothing);

      // Tap Continuar offline
      final offlineBtnFinder = find.byKey(const Key('daemon_setup_offline_button'));
      await tester.ensureVisible(offlineBtnFinder);
      await tester.tap(offlineBtnFinder);
      await tester.pumpAndSettle();

      // Gate switches to AppNavigationShell
      expect(find.byType(AppNavigationShell), findsOneWidget);
      expect(find.byType(DaemonSetupScreen), findsNothing);

      // Settings repository still has hasConfirmedConnection == false
      final savedSettings = await repository.loadSettings();
      expect(savedSettings.hasConfirmedConnection, isFalse);
    });

    testWidgets('4. Setup success persists confirmation and lands in shell', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsRepositoryProvider.overrideWithValue(repository),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(
                repository,
                const Settings(
                  baseUrl: 'http://10.0.2.2:2123',
                  hasConfirmedConnection: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: ConnectionGate(
              testConnectionOverride: (url) async {
                return {
                  'info': {
                    'title': 'CompozyOS Daemon',
                    'version': '1.0.0',
                  },
                };
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DaemonSetupScreen), findsOneWidget);

      // Tap Testar conexão
      final testBtnFinder = find.byKey(const Key('daemon_setup_test_button'));
      await tester.ensureVisible(testBtnFinder);
      await tester.tap(testBtnFinder);
      await tester.pumpAndSettle();

      // Verify connected banner appears
      expect(find.byKey(const Key('daemon_setup_success_banner')), findsOneWidget);

      // Tap Continuar
      final continueBtnFinder = find.byKey(const Key('daemon_setup_continue_button'));
      await tester.ensureVisible(continueBtnFinder);
      await tester.tap(continueBtnFinder);
      await tester.pumpAndSettle();

      // Now lands in shell
      expect(find.byType(AppNavigationShell), findsOneWidget);
      expect(find.byType(DaemonSetupScreen), findsNothing);

      // Confirmed connection persisted in settings
      final savedSettings = await repository.loadSettings();
      expect(savedSettings.hasConfirmedConnection, isTrue);
    });
  });
}
