import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/agents/data/agents_repository_provider.dart';
import 'package:compozy_app/features/automations/data/automation_repository_impl.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/main.dart';

class _InMemorySettingsRepo implements SettingsRepository {
  Settings _settings;

  _InMemorySettingsRepo([Settings? initial])
      : _settings = initial ?? const Settings(hasConfirmedConnection: true);

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

List<Override> _createOverrides() {
  final settingsRepo = _InMemorySettingsRepo(
    const Settings(hasConfirmedConnection: true),
  );
  return [
    sessionsProvider.overrideWith((ref) => Future.value(const [])),
    loopsProvider.overrideWith((ref) => Future.value(const [])),
    agentsPresenceProvider.overrideWith((ref) => Future.value(const [])),
    automationJobsProvider.overrideWith((ref) => Future.value(const [])),
    automationTriggersProvider.overrideWith((ref) => Future.value(const [])),
    automationSchedulerProvider.overrideWith(
      (ref) => Future.value(const SchedulerStatus()),
    ),
    connectionStatusProvider.overrideWith((ref) => Future.value(true)),
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
    settingsProvider.overrideWith((ref) => SettingsNotifier(settingsRepo)),
  ];
}

void main() {
  testWidgets('AppNavigationShell renders mobile layout (< 600dp) with BottomNavigationBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: _createOverrides(),
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workspace title in app bar
    expect(find.text('compozy-app'), findsOneWidget);

    // Verify BottomNavigationBar is used on mobile
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Verify nav destinations
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Loops'), findsOneWidget);
    expect(find.text('Automations'), findsOneWidget);

    // Assert Settings is NOT inside BottomNavigationBar
    expect(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Settings'),
      ),
      findsNothing,
    );

    // Switch tab to Loops
    await tester.tap(find.text('Loops'));
    await tester.pumpAndSettle();
    expect(find.text('Loops Catalog'), findsOneWidget);

    // Open workspace menu and navigate to Settings
    await tester.tap(find.byKey(const Key('app_workspace_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace_menu_settings_button')));
    await tester.pumpAndSettle();
    expect(find.text('Daemon Settings'), findsOneWidget);
  });

  testWidgets('AppNavigationShell renders desktop layout (>= 600dp) with NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: _createOverrides(),
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workspace title in app bar
    expect(find.text('compozy-app'), findsOneWidget);

    // Verify NavigationRail is used on desktop/tablet
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    // Verify rail destinations
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
  });
}
