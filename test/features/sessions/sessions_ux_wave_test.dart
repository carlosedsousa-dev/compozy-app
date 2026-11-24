import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/domain/repositories/session_repository.dart';
import 'package:compozy_app/features/sessions/presentation/session_chat_screen.dart';
import 'package:compozy_app/features/sessions/presentation/session_draft_provider.dart';
import 'package:compozy_app/features/sessions/presentation/sessions_list_screen.dart';

class _MockSessionRepo implements SessionRepository {
  List<Turn> turns = [];

  _MockSessionRepo({List<Turn>? initialTurns}) : turns = initialTurns ?? [];

  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async => [];

  @override
  Future<Session> getSession(String sessionId) async => throw UnimplementedError();

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async =>
      turns;

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
  group('Sessions UX Wave Tests (Batch 2 Verification)', () {
    testWidgets(
      '1. Needs-you ordering: sessions awaiting user action sort to the top',
      (tester) async {
        final now = DateTime.now();
        final sessions = [
          Session(
            id: 'sess-active-recent',
            name: 'Recent Active Worker',
            agent: 'fixer',
            state: 'active',
            createdAt: now.subtract(const Duration(minutes: 5)),
            updatedAt: now.subtract(const Duration(seconds: 10)),
          ),
          Session(
            id: 'sess-waiting-triage',
            name: 'Needs Approval Worker',
            agent: 'designer',
            state: 'waiting',
            createdAt: now.subtract(const Duration(hours: 1)),
            updatedAt: now.subtract(const Duration(minutes: 20)),
          ),
          Session(
            id: 'sess-blocked-triage',
            name: 'Blocked User Action Worker',
            agent: 'auditor',
            state: 'blocked',
            createdAt: now.subtract(const Duration(hours: 2)),
            updatedAt: now.subtract(const Duration(minutes: 10)),
          ),
          Session(
            id: 'sess-idle-old',
            name: 'Older Idle Session',
            agent: 'researcher',
            state: 'idle',
            createdAt: now.subtract(const Duration(days: 1)),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionsProvider.overrideWith((ref) => Future.value(sessions)),
              connectionStatusProvider.overrideWith((ref) => Future.value(true)),
            ],
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: const SessionsListScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the cards rendered in list
        final listFinder = find.byKey(const Key('sessions_list_view'));
        expect(listFinder, findsOneWidget);

        // Find individual session card widgets
        final cardBlocked = find.byKey(const Key('session_card_sess-blocked-triage'));
        final cardWaiting = find.byKey(const Key('session_card_sess-waiting-triage'));
        final cardActive = find.byKey(const Key('session_card_sess-active-recent'));
        final cardIdle = find.byKey(const Key('session_card_sess-idle-old'));

        expect(cardBlocked, findsOneWidget);
        expect(cardWaiting, findsOneWidget);
        expect(cardActive, findsOneWidget);
        expect(cardIdle, findsOneWidget);

        // Verify ordering in the render tree:
        // 'blocked' (updated 10m ago) and 'waiting' (updated 20m ago) sort above 'active' (updated 10s ago)
        final yBlocked = tester.getTopLeft(cardBlocked).dy;
        final yWaiting = tester.getTopLeft(cardWaiting).dy;
        final yActive = tester.getTopLeft(cardActive).dy;
        final yIdle = tester.getTopLeft(cardIdle).dy;

        expect(yBlocked, lessThan(yWaiting));
        expect(yWaiting, lessThan(yActive));
        expect(yActive, lessThan(yIdle));
      },
    );

    testWidgets(
      '2. Search filtering: filters by name, agent, and id with clear button and empty recovery',
      (tester) async {
        final now = DateTime.now();
        final sessions = [
          Session(
            id: 'uuid-101-alpha',
            name: 'Code Review Inspector',
            agent: 'auditor',
            state: 'active',
            createdAt: now,
            updatedAt: now,
          ),
          Session(
            id: 'uuid-202-beta',
            name: 'Mobile Layout Polish',
            agent: 'designer',
            state: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionsProvider.overrideWith((ref) => Future.value(sessions)),
              connectionStatusProvider.overrideWith((ref) => Future.value(true)),
            ],
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: const SessionsListScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both sessions visible initially
        expect(find.text('Code Review Inspector'), findsOneWidget);
        expect(find.text('Mobile Layout Polish'), findsOneWidget);

        // 1. Search by name keyword
        await tester.enterText(
          find.byKey(const Key('sessions_search_field')),
          'Review',
        );
        await tester.pumpAndSettle();

        expect(find.text('Code Review Inspector'), findsOneWidget);
        expect(find.text('Mobile Layout Polish'), findsNothing);

        // 2. Clear via clear button
        expect(find.byKey(const Key('sessions_search_clear_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('sessions_search_clear_button')));
        await tester.pumpAndSettle();

        expect(find.text('Code Review Inspector'), findsOneWidget);
        expect(find.text('Mobile Layout Polish'), findsOneWidget);

        // 3. Search by agent role
        await tester.enterText(
          find.byKey(const Key('sessions_search_field')),
          'designer',
        );
        await tester.pumpAndSettle();

        expect(find.text('Code Review Inspector'), findsNothing);
        expect(find.text('Mobile Layout Polish'), findsOneWidget);

        // 4. Search by unique ID
        await tester.enterText(
          find.byKey(const Key('sessions_search_field')),
          'uuid-101',
        );
        await tester.pumpAndSettle();

        expect(find.text('Code Review Inspector'), findsOneWidget);
        expect(find.text('Mobile Layout Polish'), findsNothing);

        // 5. Search for nonexistent term -> Empty state with Clear search action
        await tester.enterText(
          find.byKey(const Key('sessions_search_field')),
          'nonexistent-query-xyz',
        );
        await tester.pumpAndSettle();

        expect(find.text('No matching sessions'), findsOneWidget);
        expect(find.text('Clear search'), findsOneWidget);

        // Tap Clear search in empty state
        await tester.tap(find.text('Clear search'));
        await tester.pumpAndSettle();

        expect(find.text('Code Review Inspector'), findsOneWidget);
        expect(find.text('Mobile Layout Polish'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Scroll-to-latest visibility and unread stream indicator',
      (tester) async {
        final session = Session(
          id: 'sess-scroll-test',
          name: 'Scroll & Stream Session',
          agent: 'fixer',
          state: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final longTurns = List.generate(
          20,
          (i) => Turn(
            turnId: 'turn-$i',
            userMessage: 'User question turn index #$i: detailed request content',
            agentMessage:
                'Agent response turn index #$i: comprehensive step-by-step breakdown with explanations and code snippets.',
            status: 'completed',
            toolCalls: const [],
          ),
        );

        final streamController = StreamController<SessionStreamEvent>.broadcast();
        addTearDown(() => streamController.close());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionRepositoryProvider.overrideWithValue(_MockSessionRepo(initialTurns: longTurns)),
              sessionStreamProvider(session.id).overrideWith((ref) => streamController.stream),
            ],
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: SessionChatScreen(session: session),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final listFinder = find.byKey(const Key('transcript_list_view'));
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: listFinder, matching: find.byType(Scrollable)),
        );

        // Jump to the bottom of the list
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();

        // At the bottom, scroll-to-latest button is not shown
        expect(find.byKey(const Key('chat_scroll_to_latest_button')), findsNothing);

        // Scroll up to the top (>200dp away from bottom)
        scrollable.position.jumpTo(0.0);
        await tester.pumpAndSettle();

        // Button is now visible
        expect(find.byKey(const Key('chat_scroll_to_latest_button')), findsOneWidget);
        expect(find.byKey(const Key('scroll_to_latest_unread_dot')), findsNothing);

        // Incoming stream event while scrolled up triggers unread badge
        streamController.add(
          const SessionTextDeltaEvent(
            sessionId: 'sess-scroll-test',
            turnId: 'turn-stream-live',
            textDelta: 'Incoming token while away...',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('chat_scroll_to_latest_button')), findsOneWidget);
        expect(find.byKey(const Key('scroll_to_latest_unread_dot')), findsOneWidget);

        // Tapping the scroll button returns to bottom
        await tester.tap(find.byKey(const Key('chat_scroll_to_latest_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chat_scroll_to_latest_button')), findsNothing);
      },
    );

    testWidgets(
      '4. Draft persistence: typed prompt text survives leaving and re-entering chat',
      (tester) async {
        final session = Session(
          id: 'sess-draft-test',
          name: 'Draft Session',
          agent: 'designer',
          state: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Screen 1: Enter text
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: SessionChatScreen(
                session: session,
                initialTurns: const [],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('prompt_input_field')),
          'Work-in-progress unsent prompt draft',
        );
        await tester.pump();

        // Verify draft provider holds the string
        expect(
          container.read(sessionDraftPromptProvider('sess-draft-test')),
          'Work-in-progress unsent prompt draft',
        );

        // Navigate away: pump replacement screen
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: Text('Another Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Another Screen'), findsOneWidget);
        expect(find.byKey(const Key('prompt_input_field')), findsNothing);

        // Return to SessionChatScreen for same session
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: SessionChatScreen(
                session: session,
                initialTurns: const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Prompt text was restored
        final field = tester.widget<TextField>(find.byKey(const Key('prompt_input_field')));
        expect(field.controller?.text, 'Work-in-progress unsent prompt draft');
      },
    );

    testWidgets(
      '5. Send button tap target semantics and size: >= 48dp target with Semantics descriptors',
      (tester) async {
        final session = Session(
          id: 'sess-semantics-test',
          name: 'Semantics Test Session',
          agent: 'fixer',
          state: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: CompozyTheme.darkTheme,
              home: SessionChatScreen(
                session: session,
                initialTurns: const [],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final sendButtonFinder = find.byKey(const Key('prompt_send_button'));
        expect(sendButtonFinder, findsOneWidget);

        // Check Semantics widget
        final semanticsFinder = find.ancestor(
          of: sendButtonFinder,
          matching: find.byType(Semantics),
        );
        expect(semanticsFinder, findsWidgets);

        final semanticsWidget = tester.widget<Semantics>(semanticsFinder.first);
        expect(semanticsWidget.properties.button, isTrue);
        expect(semanticsWidget.properties.label, 'Send prompt');
        expect(semanticsWidget.properties.enabled, isFalse); // Initially empty input

        // Enter text to enable button
        await tester.enterText(find.byKey(const Key('prompt_input_field')), 'Hello');
        await tester.pump();

        final enabledSemanticsWidget = tester.widget<Semantics>(semanticsFinder.first);
        expect(enabledSemanticsWidget.properties.enabled, isTrue);

        // Check tap target size: minimum width and height >= 48dp
        final buttonSize = tester.getSize(sendButtonFinder);
        expect(buttonSize.width, greaterThanOrEqualTo(48.0));
        expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      },
    );
  });
}
