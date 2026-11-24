import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/agents/data/agents_repository_provider.dart';
import 'package:compozy_app/features/agents/presentation/agents_screen.dart';

void main() {
  final testAgents = [
    const AgentPresence(
      agent: AgentDefinition(
        name: 'fixer',
        label: 'Fixer',
        kind: 'on_demand',
        appearance: AgentAppearance(
          avatar: 'generated',
          colorHex: '#d97706',
          seed: 'fixer',
        ),
        toolsets: ['compozy__terminal'],
        categoryPath: ['Engineering'],
        origin: 'global',
        effectiveRuntime: AgentEffectiveRuntime(
          provider: 'agy',
          model: 'gemini-3.8-flash',
          reasoningEffort: 'high',
          permissions: 'approve-all',
        ),
      ),
      status: AgentPresenceStatus.needsYou,
      workingSessionsCount: 0,
      waitingSessionsCount: 1,
      totalSessionsCount: 2,
    ),
    const AgentPresence(
      agent: AgentDefinition(
        name: 'designer',
        label: 'Designer',
        kind: 'on_demand',
        provider: 'agy',
        model: 'gemini-3.8-flash',
        appearance: AgentAppearance(
          avatar: 'generated',
          colorHex: '#7c5cff',
          seed: 'designer',
        ),
        toolsets: ['compozy__catalog'],
        categoryPath: ['CompozyOS'],
        origin: 'global',
        effectiveRuntime: AgentEffectiveRuntime(
          provider: 'agy',
          model: 'gemini-3.8-flash',
          reasoningEffort: 'high',
          permissions: 'approve-all',
        ),
      ),
      status: AgentPresenceStatus.working,
      workingSessionsCount: 1,
      waitingSessionsCount: 0,
      totalSessionsCount: 3,
    ),
    const AgentPresence(
      agent: AgentDefinition(
        name: 'oracle',
        label: 'Oracle',
        kind: 'on_demand',
        appearance: AgentAppearance(
          avatar: 'generated',
          colorHex: '#8b5cf6',
          seed: 'oracle',
        ),
        toolsets: ['compozy__catalog'],
        categoryPath: ['CompozyOS'],
        origin: 'global',
        effectiveRuntime: AgentEffectiveRuntime(
          provider: 'agy',
          model: 'gemini-3.8-flash',
          reasoningEffort: 'medium',
        ),
      ),
      status: AgentPresenceStatus.idle,
      workingSessionsCount: 0,
      waitingSessionsCount: 0,
      totalSessionsCount: 1,
    ),
  ];

  group('AgentsScreen Presentation & Presence Hub', () {
    testWidgets('renders skeleton loading view without bare spinner on initial load', (tester) async {
      final completer = Completer<List<AgentPresence>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => completer.future),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(const Key('agents_loading_skeletons')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete(testAgents);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_loading_skeletons')), findsNothing);
      expect(find.text('Designer'), findsOneWidget);
    });

    testWidgets('renders header summary with active, needs-attention, and total counts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total count badge in header
      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Summary Pills
      expect(find.text('1 working'), findsOneWidget);
      expect(find.text('1 needs attention'), findsOneWidget);
    });

    testWidgets('prioritizes "Needs you" agents first and shows status signal dots', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Fixer (Needs you) appears first in the list
      final finderFixer = find.text('Fixer');
      final finderDesigner = find.text('Designer');
      final finderOracle = find.text('Oracle');

      expect(finderFixer, findsOneWidget);
      expect(finderDesigner, findsOneWidget);
      expect(finderOracle, findsOneWidget);

      final fixerOffset = tester.getTopLeft(finderFixer).dy;
      final designerOffset = tester.getTopLeft(finderDesigner).dy;
      final oracleOffset = tester.getTopLeft(finderOracle).dy;

      // Needs you (Fixer) < Working (Designer) < Idle (Oracle)
      expect(fixerOffset, lessThan(designerOffset));
      expect(designerOffset, lessThan(oracleOffset));

      // Verify signal badges
      expect(find.byKey(const Key('agent_status_badge_needsYou')), findsOneWidget);
      expect(find.byKey(const Key('agent_status_badge_working')), findsOneWidget);
      expect(find.byKey(const Key('agent_status_badge_idle')), findsOneWidget);

      // Verify status dot on avatar
      expect(find.byKey(const Key('agent_avatar_status_dot_needsYou')), findsOneWidget);
      expect(find.byKey(const Key('agent_avatar_status_dot_working')), findsOneWidget);
      expect(find.byKey(const Key('agent_avatar_status_dot_idle')), findsOneWidget);
    });

    testWidgets('filters agents by status chip (Working, Needs you, Idle, All)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Filter by 'Working'
      await tester.tap(find.byKey(const Key('filter_chip_working')));
      await tester.pumpAndSettle();

      expect(find.text('Designer'), findsOneWidget);
      expect(find.text('Fixer'), findsNothing);
      expect(find.text('Oracle'), findsNothing);

      // Filter by 'Needs you'
      await tester.tap(find.byKey(const Key('filter_chip_needs_you')));
      await tester.pumpAndSettle();

      expect(find.text('Fixer'), findsOneWidget);
      expect(find.text('Designer'), findsNothing);
      expect(find.text('Oracle'), findsNothing);

      // Filter by 'Idle'
      await tester.tap(find.byKey(const Key('filter_chip_idle')));
      await tester.pumpAndSettle();

      expect(find.text('Oracle'), findsOneWidget);
      expect(find.text('Designer'), findsNothing);
      expect(find.text('Fixer'), findsNothing);

      // Return to 'All'
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('Designer'), findsOneWidget);
      expect(find.text('Fixer'), findsOneWidget);
      expect(find.text('Oracle'), findsOneWidget);
    });

    testWidgets('filters agents by search query and offers clear search button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search by category 'Engineering'
      await tester.enterText(find.byKey(const Key('agents_search_field')), 'Engineering');
      await tester.pumpAndSettle();

      expect(find.text('Fixer'), findsOneWidget);
      expect(find.text('Designer'), findsNothing);
      expect(find.text('Oracle'), findsNothing);

      // Clear search button visible
      expect(find.byKey(const Key('agents_search_clear_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('agents_search_clear_button')));
      await tester.pumpAndSettle();

      expect(find.text('Designer'), findsOneWidget);
      expect(find.text('Fixer'), findsOneWidget);
      expect(find.text('Oracle'), findsOneWidget);
    });

    testWidgets('empty state with active filter offers "Clear filters" to restore', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter query with no matches
      await tester.enterText(find.byKey(const Key('agents_search_field')), 'nonexistent');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_empty_view')), findsOneWidget);
      expect(find.text('No matching agents'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      // Tap 'Clear filters'
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Designer'), findsOneWidget);
      expect(find.text('Fixer'), findsOneWidget);
      expect(find.text('Oracle'), findsOneWidget);
    });

    testWidgets('renders empty state when daemon returns 0 agents', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(const [])),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_empty_view')), findsOneWidget);
      expect(find.text('No agents found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders error view with retry action on daemon error', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) {
              if (retried) {
                return Future.value(testAgents);
              }
              return Future.error(Exception('Connection refused'));
            }),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_error_view')), findsOneWidget);
      expect(find.text('Failed to load agents'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      retried = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Designer'), findsOneWidget);
    });

    testWidgets('tapping agent card opens details bottom sheet with toolsets and runtime', (tester) async {
      const mockActivity = AgentActivity(
        costByProject: [
          AgentProjectCost(
            workspaceId: 'ws_3e99',
            scope: 'compozy-app',
            usdEstimate: 0.088,
            tokens: 24500000,
          ),
        ],
        busyByHour: [
          AgentBusyHour(weekday: 1, hour: 14, events: 120),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
            agentActivityProvider('designer').overrideWith((ref) => Future.value(mockActivity)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Designer agent card
      await tester.tap(find.text('Designer'));
      await tester.pumpAndSettle();

      // Bottom sheet is visible
      expect(find.byKey(const Key('agent_details_bottom_sheet')), findsOneWidget);

      // Verify runtime section
      expect(find.text('EFFECTIVE RUNTIME'), findsOneWidget);
      expect(find.text('agy · gemini-3.8-flash'), findsWidgets);

      // Verify toolset
      expect(find.text('compozy__catalog'), findsOneWidget);

      // Verify activity telemetry
      expect(find.text('ACTIVITY & TELEMETRY'), findsOneWidget);
      expect(find.text('24.5M'), findsOneWidget);
      expect(find.text('\$0.088'), findsOneWidget);
      expect(find.text('compozy-app'), findsOneWidget);

      // Dismiss bottom sheet
      await tester.tap(find.byKey(const Key('close_agent_details_sheet_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agent_details_bottom_sheet')), findsNothing);
    });

    testWidgets('renders mobile layout (<600dp) with ListView', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const AgentsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_list_view')), findsOneWidget);
      expect(find.byKey(const Key('agents_grid_view')), findsNothing);
    });

    testWidgets('renders desktop layout (>=600dp) with GridView without text scale overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsPresenceProvider.overrideWith((ref) => Future.value(testAgents)),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(1024, 768),
                textScaler: TextScaler.linear(1.6),
              ),
              child: const AgentsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('agents_grid_view')), findsOneWidget);
      expect(find.byKey(const Key('agents_list_view')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
