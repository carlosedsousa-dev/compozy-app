import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/domain/repositories/session_repository.dart';
import 'package:compozy_app/features/sessions/presentation/session_chat_screen.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/subagents_drawer.dart';

class _FakeSessionRepo implements SessionRepository {
  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async => [];

  @override
  Future<Session> getSession(String sessionId) async => throw UnimplementedError();

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async => [];

  @override
  Future<void> sendPrompt(String sessionId, String message) async {}

  @override
  Future<void> respondToApproval(
    String sessionId, {
    required bool approved,
    String? approvalId,
  }) async {}
}

void main() {
  final testRootSession = Session(
    id: 'root-sess-1',
    name: 'Loop Orchestrator Main',
    agent: 'orchestrator',
    state: 'active',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  final testSubagents = [
    const SubagentItem(
      id: 'sub-1',
      role: 'designer',
      name: 'Loop Goal Designer',
      state: 'working',
      model: 'gemini-3.8-flash',
      runtimeTag: 'runtime: default',
      brief: 'Refactor mobile visual hierarchy and drawer tokens',
      depth: 0,
    ),
    const SubagentItem(
      id: 'sub-2',
      role: 'fixer',
      name: 'Code Remediation Lane',
      state: 'waiting',
      model: 'claude-3-7-sonnet',
      runtimeTag: 'workspace: inherit',
      brief: 'Awaiting completion of upstream test passes',
      depth: 1,
    ),
    const SubagentItem(
      id: 'sub-3',
      role: 'researcher',
      name: 'Dependency Auditor',
      state: 'stopped',
      model: 'gpt-4o',
      runtimeTag: 'depth: 1',
      depth: 1,
    ),
  ];

  group('testSubagentHierarchyDrawer (IT-009)', () {
    testWidgets('renders subagents tree with role, status dot, model badge, and runtime tags (US-009.AC-1)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              endDrawer: SubagentsDrawer(
                session: testRootSession,
                subagents: testSubagents,
              ),
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Drawer and Header
      expect(find.byKey(const Key('subagents_drawer')), findsOneWidget);
      expect(find.text('Subagents Hierarchy'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
      expect(find.byKey(const Key('subagents_drawer_close')), findsOneWidget);

      // Root session context
      expect(find.text('Root Session'), findsOneWidget);
      expect(find.text('Loop Orchestrator Main'), findsOneWidget);

      // Subagent items
      expect(find.byKey(const Key('subagents_list_view')), findsOneWidget);

      // Roles
      expect(find.byKey(const Key('subagent_role_sub-1')), findsOneWidget);
      expect(find.text('designer'), findsOneWidget);
      expect(find.byKey(const Key('subagent_role_sub-2')), findsOneWidget);
      expect(find.text('fixer'), findsOneWidget);
      expect(find.byKey(const Key('subagent_role_sub-3')), findsOneWidget);
      expect(find.text('researcher'), findsOneWidget);

      // Status dots
      expect(find.byKey(const Key('subagent_status_dot_sub-1')), findsOneWidget);
      expect(find.byKey(const Key('subagent_status_dot_sub-2')), findsOneWidget);
      expect(find.byKey(const Key('subagent_status_dot_sub-3')), findsOneWidget);

      // Names
      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('Code Remediation Lane'), findsOneWidget);
      expect(find.text('Dependency Auditor'), findsOneWidget);

      // Model badges
      expect(find.byKey(const Key('subagent_model_sub-1')), findsOneWidget);
      expect(find.text('gemini-3.8-flash'), findsOneWidget);
      expect(find.byKey(const Key('subagent_model_sub-2')), findsOneWidget);
      expect(find.text('claude-3-7-sonnet'), findsOneWidget);
      expect(find.byKey(const Key('subagent_model_sub-3')), findsOneWidget);
      expect(find.text('gpt-4o'), findsOneWidget);

      // Runtime tags
      expect(find.byKey(const Key('subagent_runtime_tag_sub-1')), findsOneWidget);
      expect(find.text('runtime: default'), findsOneWidget);
      expect(find.byKey(const Key('subagent_runtime_tag_sub-2')), findsOneWidget);
      expect(find.text('workspace: inherit'), findsOneWidget);
      expect(find.byKey(const Key('subagent_runtime_tag_sub-3')), findsOneWidget);
      expect(find.text('depth: 1'), findsOneWidget);

      // Brief text
      expect(find.text('Refactor mobile visual hierarchy and drawer tokens'), findsOneWidget);
      expect(find.text('Awaiting completion of upstream test passes'), findsOneWidget);
    });

    testWidgets('renders nested child lanes with tree hierarchy indentation (handoff.jpg)', (tester) async {
      final treeSubagents = [
        const SubagentItem(
          id: 'parent-1',
          role: 'fixer',
          name: 'Parent Review Fixer',
          state: 'working',
          children: [
            SubagentItem(
              id: 'child-1',
              role: 'researcher',
              name: 'Child Codebase Explorer',
              state: 'working',
              model: 'gemini-3.8-flash',
              runtimeTag: 'depth: 1',
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              endDrawer: SubagentsDrawer(
                subagents: treeSubagents,
              ),
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Parent Review Fixer'), findsOneWidget);
      expect(find.text('Child Codebase Explorer'), findsOneWidget);
      expect(find.text('L1'), findsOneWidget); // Level 1 tree badge
    });

    testWidgets('renders empty state when no subagents are spawned', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              endDrawer: SubagentsDrawer(
                subagents: [],
              ),
              body: Center(child: Text('Body')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subagents_empty_state')), findsOneWidget);
      expect(find.text('No Subagents Spawned'), findsOneWidget);
      expect(find.text('This session has not delegated work to child lanes.'), findsOneWidget);
    });

    testWidgets('triggers onSubagentTap callback when subagent item is clicked', (tester) async {
      SubagentItem? tappedItem;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              endDrawer: SubagentsDrawer(
                subagents: testSubagents,
                onSubagentTap: (item) {
                  tappedItem = item;
                },
              ),
              body: Center(child: Text('Body')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subagent_item_sub-1')));
      await tester.pumpAndSettle();

      expect(tappedItem, isNotNull);
      expect(tappedItem!.id, equals('sub-1'));
      expect(tappedItem!.role, equals('designer'));
    });

    testWidgets('triggers onClose callback or closes drawer when close button is tapped', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              endDrawer: SubagentsDrawer(
                subagents: testSubagents,
                onClose: () {
                  closed = true;
                },
              ),
              body: Center(child: Text('Body')),
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('subagents_drawer_close')), findsOneWidget);
      await tester.tap(find.byKey(const Key('subagents_drawer_close')));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets('opens SubagentsDrawer from SessionChatScreen via top app bar action', (tester) async {
      final fakeRepo = _FakeSessionRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
            subagentsProvider('root-sess-1').overrideWithValue(testSubagents),
          ],
          child: MaterialApp(
            home: SessionChatScreen(
              session: testRootSession,
              initialTurns: const [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar button for subagents drawer
      final buttonFinder = find.byKey(const Key('chat_subagents_button'));
      expect(buttonFinder, findsOneWidget);

      // Tap to open end drawer
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Subagents drawer is now open
      expect(find.byKey(const Key('subagents_drawer')), findsOneWidget);
      expect(find.text('Subagents Hierarchy'), findsOneWidget);
      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('designer'), findsOneWidget);
    });
  });
}
