import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/presentation/app_shell.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/agents/data/agents_repository_provider.dart';
import 'package:compozy_app/features/agents/presentation/agents_screen.dart';
import 'package:compozy_app/features/automations/data/automation_repository_impl.dart';
import 'package:compozy_app/features/automations/presentation/automations_screen.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/loops/presentation/loops_catalog_screen.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/presentation/sessions_list_screen.dart';
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

List<Override> _createOverrides(_MockSettingsRepository repo) {
  return [
    sessionsProvider.overrideWith((ref) => Future.value(const [])),
    loopsProvider.overrideWith((ref) => Future.value(const [])),
    agentsPresenceProvider.overrideWith((ref) => Future.value(const [])),
    automationJobsProvider.overrideWith((ref) => Future.value(const [])),
    automationTriggersProvider.overrideWith((ref) => Future.value(const [])),
    automationSchedulerProvider.overrideWith(
      (ref) => Future.value(const SchedulerStatus()),
    ),
    settingsRepositoryProvider.overrideWithValue(repo),
    settingsProvider.overrideWith((ref) => SettingsNotifier(repo)),
    connectionStatusProvider.overrideWith((ref) => Future.value(true)),
  ];
}

void main() {
  group('testAppShellSettingsTab (WT-004 - Wave 2 IA Contract)', () {
    testWidgets(
      'renders four destinations on mobile BottomNavigationBar, asserts Settings is NOT in bar, and navigates to SettingsScreen via workspace menu',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _MockSettingsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _createOverrides(repo),
            child: const MaterialApp(
              home: AppNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Mobile BottomNavigationBar is present; NavigationRail is absent
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);

        // Verify the 4 destinations exist in BottomNavigationBar
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Agents'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Automations'), findsOneWidget);

        // Assert Settings is NOT a bottom navigation bar item
        expect(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('Settings'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(Icons.tune),
          ),
          findsNothing,
        );

        // Open workspace menu from top bar button
        expect(find.byKey(const Key('app_workspace_menu_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('app_workspace_menu_button')));
        await tester.pumpAndSettle();

        // Workspace menu sheet is displayed with identity, connection, theme toggle, and settings row
        expect(find.byKey(const Key('workspace_menu_sheet')), findsOneWidget);
        expect(find.text('compozy-app'), findsWidgets);
        expect(find.text('Connection'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.byKey(const Key('workspace_menu_settings_button')), findsOneWidget);

        // Tap Settings row in workspace menu sheet
        await tester.tap(find.byKey(const Key('workspace_menu_settings_button')));
        await tester.pumpAndSettle();

        // Verify sheet closed and SettingsScreen is pushed
        expect(find.byKey(const Key('workspace_menu_sheet')), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Daemon Settings'), findsOneWidget);
        expect(find.byKey(const Key('settings_base_url_field')), findsOneWidget);
        expect(find.byKey(const Key('settings_test_connection_button')), findsOneWidget);
        expect(find.byKey(const Key('settings_save_button')), findsOneWidget);

        // Verify back button pops back to shell
        expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('settings_back_button')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'renders four destinations on desktop NavigationRail, asserts Settings is NOT in rail, and navigates to SettingsScreen via workspace menu',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _MockSettingsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _createOverrides(repo),
            child: const MaterialApp(
              home: AppNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Desktop NavigationRail is present; BottomNavigationBar is absent
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);

        // Verify the 4 destinations exist in NavigationRail
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Agents'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Automations'), findsOneWidget);

        // Assert Settings is NOT in NavigationRail
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text('Settings'),
          ),
          findsNothing,
        );

        // Open workspace menu and navigate to SettingsScreen
        await tester.tap(find.byKey(const Key('app_workspace_menu_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('workspace_menu_sheet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('workspace_menu_settings_button')));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Daemon Settings'), findsOneWidget);
        expect(find.byKey(const Key('settings_screen')), findsOneWidget);

        // Pop back
        await tester.tap(find.byKey(const Key('settings_back_button')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(NavigationRail), findsOneWidget);
      },
    );

    testWidgets(
      'switches cleanly between Sessions, Agents, Loops, and Automations',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _MockSettingsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _createOverrides(repo),
            child: const MaterialApp(
              home: AppNavigationShell(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Starts on Sessions (index 0)
        expect(find.byType(SessionsListScreen), findsOneWidget);
        expect(find.byType(AgentsScreen), findsNothing);
        expect(find.byType(LoopsCatalogScreen), findsNothing);
        expect(find.byType(AutomationsScreen), findsNothing);

        // Switch to Agents (index 1)
        await tester.tap(find.text('Agents'));
        await tester.pumpAndSettle();
        expect(find.byType(AgentsScreen), findsOneWidget);
        expect(find.byType(SessionsListScreen), findsNothing);

        // Switch to Loops (index 2)
        await tester.tap(find.text('Loops'));
        await tester.pumpAndSettle();
        expect(find.byType(LoopsCatalogScreen), findsOneWidget);
        expect(find.byType(AgentsScreen), findsNothing);

        // Switch to Automations (index 3)
        await tester.tap(find.text('Automations'));
        await tester.pumpAndSettle();
        expect(find.byType(AutomationsScreen), findsOneWidget);
        expect(find.byType(LoopsCatalogScreen), findsNothing);

        // Switch back to Sessions (index 0)
        await tester.tap(find.text('Sessions'));
        await tester.pumpAndSettle();
        expect(find.byType(SessionsListScreen), findsOneWidget);
        expect(find.byType(AutomationsScreen), findsNothing);
      },
    );

    testWidgets(
      'renders 4 destinations without overflow or clipping on 320dp-wide screen with 1.3x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final repo = _MockSettingsRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: _createOverrides(repo),
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: CompozyTheme.darkTheme,
                home: const AppNavigationShell(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify no Flutter overflow exceptions occurred
        expect(tester.takeException(), isNull);

        // Verify all 4 destination labels are present
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Agents'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Automations'), findsOneWidget);

        // Verify all 4 navigation icons are rendered
        expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
        expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
        expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
        expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);

        // Verify bottom bar renders cleanly without Settings
        expect(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('Settings'),
          ),
          findsNothing,
        );
      },
    );
  });
}
