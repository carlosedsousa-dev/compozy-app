import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/connection/presentation/daemon_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    // Reset view physical size if modified in tests
  });

  group('DaemonSetupScreen', () {
    testWidgets('Candidate shortcuts fill the URL field', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DaemonSetupScreen(isAndroid: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Localhost candidate shortcut
      await tester.tap(find.byKey(const Key('candidate_localhost')));
      await tester.pumpAndSettle();

      final urlFieldFinder = find.byKey(const Key('daemon_setup_url_field'));
      expect(urlFieldFinder, findsOneWidget);

      final textField = tester.widget<TextFormField>(urlFieldFinder);
      expect(textField.controller?.text, equals('http://localhost:2123'));

      // Tap Emulator candidate shortcut
      await tester.tap(find.byKey(const Key('candidate_emulator')));
      await tester.pumpAndSettle();

      expect(textField.controller?.text, equals('http://10.0.2.2:2123'));
    });

    testWidgets('Test connection success displays connected status, persists URL + confirmation on continue', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      bool connectedCallbackCalled = false;

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
            home: DaemonSetupScreen(
              isAndroid: true,
              onConnected: () {
                connectedCallbackCalled = true;
              },
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

      // Tap Test connection
      final testBtnFinder = find.byKey(const Key('daemon_setup_test_button'));
      await tester.ensureVisible(testBtnFinder);
      await tester.tap(testBtnFinder);
      await tester.pumpAndSettle();

      // Verify connected state banner appears
      expect(find.byKey(const Key('daemon_setup_success_banner')), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('CompozyOS Daemon · v1.0.0'), findsOneWidget);

      // Verify primary button changed to Continue
      final continueBtnFinder = find.byKey(const Key('daemon_setup_continue_button'));
      expect(continueBtnFinder, findsOneWidget);

      // Tap Continue
      await tester.ensureVisible(continueBtnFinder);
      await tester.tap(continueBtnFinder);
      await tester.pumpAndSettle();

      expect(connectedCallbackCalled, isTrue);

      // Verify URL and confirmation persisted
      final savedSettings = await repository.loadSettings();
      expect(savedSettings.baseUrl, equals('http://10.0.2.2:2123'));
      expect(savedSettings.hasConfirmedConnection, isTrue);
    });

    testWidgets('Test connection failure shows honest error and does not persist confirmation', (tester) async {
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
          child: MaterialApp(
            home: DaemonSetupScreen(
              testConnectionOverride: (url) async {
                return null; // Simulates connection failure
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Test connection
      final testBtnFinder = find.byKey(const Key('daemon_setup_test_button'));
      await tester.ensureVisible(testBtnFinder);
      await tester.tap(testBtnFinder);
      await tester.pumpAndSettle();

      // Error banner should be visible
      expect(find.byKey(const Key('daemon_setup_error_banner')), findsOneWidget);
      expect(find.text('Connection failed'), findsOneWidget);

      // Confirmation is NOT persisted
      final savedSettings = await repository.loadSettings();
      expect(savedSettings.hasConfirmedConnection, isFalse);

      // Primary button is still Test connection (allows retry)
      expect(find.byKey(const Key('daemon_setup_test_button')), findsOneWidget);
      expect(find.byKey(const Key('daemon_setup_continue_button')), findsNothing);
    });

    testWidgets('Continue offline enters shell without marking connection confirmed', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(preferences: prefs);

      bool offlineCallbackCalled = false;

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
          child: MaterialApp(
            home: DaemonSetupScreen(
              onContinueOffline: () {
                offlineCallbackCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue offline
      final offlineBtnFinder = find.byKey(const Key('daemon_setup_offline_button'));
      await tester.ensureVisible(offlineBtnFinder);
      await tester.tap(offlineBtnFinder);
      await tester.pumpAndSettle();

      expect(offlineCallbackCalled, isTrue);

      // Flag remains false
      final savedSettings = await repository.loadSettings();
      expect(savedSettings.hasConfirmedConnection, isFalse);
    });

    testWidgets('Inline URL validation rejects invalid scheme or empty host', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DaemonSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final urlField = find.byKey(const Key('daemon_setup_url_field'));
      final testBtnFinder = find.byKey(const Key('daemon_setup_test_button'));

      // Enter invalid URL
      await tester.enterText(urlField, 'ftp://invalid-url');
      await tester.ensureVisible(testBtnFinder);
      await tester.tap(testBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Scheme must be http or https'), findsOneWidget);

      // Enter empty URL
      await tester.enterText(urlField, '');
      await tester.ensureVisible(testBtnFinder);
      await tester.tap(testBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Enter the daemon address'), findsOneWidget);
    });

    testWidgets('Renders Android helper text on Android', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DaemonSetupScreen(isAndroid: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('On Android, localhost refers to the device itself'),
        findsOneWidget,
      );
    });
  });
}
