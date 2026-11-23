import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/network/api_exceptions.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/domain/repositories/session_repository.dart';
import 'package:compozy_app/features/sessions/presentation/session_chat_screen.dart';

class _FakeSessionRepository implements SessionRepository {
  List<Turn> turns;
  String? lastPromptSessionId;
  String? lastPromptMessage;
  Exception? sendPromptError;
  int getHistoryCalls = 0;

  _FakeSessionRepository({List<Turn>? initialTurns})
      : turns = initialTurns ?? [];

  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async => [];

  @override
  Future<Session> getSession(String sessionId) async => throw UnimplementedError();

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async {
    getHistoryCalls++;
    return turns;
  }

  @override
  Future<void> sendPrompt(String sessionId, String message) async {
    lastPromptSessionId = sessionId;
    lastPromptMessage = message;
    if (sendPromptError != null) {
      throw sendPromptError!;
    }
  }
}

void main() {
  final testSession = Session(
    id: 'sess-1',
    name: 'Loop Goal Designer',
    agent: 'designer',
    state: 'active',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  final testTurns = [
    const Turn(
      turnId: 'turn-1',
      userMessage: 'Analyze repository structure',
      agentMessage: 'Found 3 dart packages in workspace.\n\n```dart\nvoid main() {}\n```',
      status: 'completed',
      toolCalls: ['compozy__tool_search', 'read_file'],
    ),
    const Turn(
      turnId: 'turn-2',
      userMessage: 'Run the test suite now',
      agentMessage: 'All test suites passed cleanly with 0 failures.',
      status: 'completed',
      toolCalls: ['run_command'],
    ),
  ];

  group('testSessionChatScreen (IT-003)', () {
    testWidgets('renders bubbles, tool pills, and app bar with session details', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top app bar verification
      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('designer'), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
      expect(find.byKey(const Key('chat_back_button')), findsOneWidget);

      // User chat bubbles
      expect(find.text('Analyze repository structure'), findsOneWidget);
      expect(find.text('Run the test suite now'), findsOneWidget);

      // Agent chat bubbles
      expect(find.textContaining('Found 3 dart packages'), findsOneWidget);
      expect(find.textContaining('All test suites passed'), findsOneWidget);

      // Tool pills
      expect(find.text('2 tools executed'), findsOneWidget);
      expect(find.text('run_command'), findsOneWidget);

      // Prompt input field & send button
      expect(find.byKey(const Key('prompt_input_field')), findsOneWidget);
      expect(find.byKey(const Key('prompt_send_button')), findsOneWidget);
    });

    testWidgets('expands and collapses tool pills on tap', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Before tap: individual tools inside turn-1 are collapsed
      expect(find.byKey(const Key('tool_call_turn-1_compozy__tool_search')), findsNothing);
      expect(find.byKey(const Key('tool_call_turn-1_read_file')), findsNothing);

      // Tap toggle for turn-1
      await tester.tap(find.byKey(const Key('tool_pill_toggle_turn-1')));
      await tester.pumpAndSettle();

      // Expanded: individual tools now visible
      expect(find.byKey(const Key('tool_call_turn-1_compozy__tool_search')), findsOneWidget);
      expect(find.byKey(const Key('tool_call_turn-1_read_file')), findsOneWidget);

      // Tap toggle again to collapse
      await tester.tap(find.byKey(const Key('tool_pill_toggle_turn-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tool_call_turn-1_compozy__tool_search')), findsNothing);
      expect(find.byKey(const Key('tool_call_turn-1_read_file')), findsNothing);
    });

    testWidgets('sends prompt with optimistic bubble and updates transcript (US-003.AC-2, US-003.AC-3)', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: [testTurns.first]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Type prompt text
      await tester.enterText(find.byKey(const Key('prompt_input_field')), 'Implement feature Y');
      await tester.pump();

      // Update repo turns to return feature Y response on next fetch
      fakeRepo.turns = [
        testTurns.first,
        const Turn(
          turnId: 'turn-new',
          userMessage: 'Implement feature Y',
          agentMessage: 'Feature Y has been successfully implemented.',
          status: 'completed',
          toolCalls: [],
        ),
      ];

      // Tap send button
      await tester.tap(find.byKey(const Key('prompt_send_button')));
      await tester.pump();

      // Optimistic bubble appears immediately
      expect(find.text('Implement feature Y'), findsOneWidget);
      expect(fakeRepo.lastPromptMessage, 'Implement feature Y');
      expect(fakeRepo.lastPromptSessionId, 'sess-1');

      // Input field was cleared
      final inputField = tester.widget<TextField>(find.byKey(const Key('prompt_input_field')));
      expect(inputField.controller?.text, isEmpty);

      // Settle after async history refresh
      await tester.pumpAndSettle();

      // Transcript now contains agent response
      expect(find.text('Feature Y has been successfully implemented.'), findsOneWidget);
    });

    testWidgets('disables send button when input is empty or whitespace only (US-003.EC-1)', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Input is empty: tap send button should do nothing
      await tester.tap(find.byKey(const Key('prompt_send_button')));
      await tester.pump();
      expect(fakeRepo.lastPromptMessage, isNull);

      // Input has only whitespace: enter whitespace
      await tester.enterText(find.byKey(const Key('prompt_input_field')), '   \t\n  ');
      await tester.pump();

      await tester.tap(find.byKey(const Key('prompt_send_button')));
      await tester.pump();
      expect(fakeRepo.lastPromptMessage, isNull);
    });

    testWidgets('disables input and send button when session is busy or stopped', (tester) async {
      // Stopped session
      final stoppedSession = testSession.copyWith(state: 'stopped');
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: stoppedSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Guidance banner is shown
      expect(find.text('Session is stopped. Prompting is disabled.'), findsOneWidget);

      // Text field is disabled
      final inputField = tester.widget<TextField>(find.byKey(const Key('prompt_input_field')));
      expect(inputField.enabled, isFalse);

      // Send button is disabled
      await tester.tap(find.byKey(const Key('prompt_send_button')));
      await tester.pump();
      expect(fakeRepo.lastPromptMessage, isNull);
    });

    testWidgets('shows guidance banner when session is busy', (tester) async {
      final busySession = testSession.copyWith(state: 'busy');
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: busySession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Session is currently busy running a turn.'), findsOneWidget);
    });

    testWidgets('handles prompt failure by displaying error snackbar and restoring prompt text (US-003.EC-2)', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);
      fakeRepo.sendPromptError = SessionBusyException(message: 'Session busy');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter prompt
      await tester.enterText(find.byKey(const Key('prompt_input_field')), 'Try this command');
      await tester.pump();

      // Send prompt
      await tester.tap(find.byKey(const Key('prompt_send_button')));
      await tester.pumpAndSettle();

      // Error snackbar is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Session is busy. Please wait before sending another prompt.'), findsOneWidget);

      // Prompt text is restored back into text field
      final inputField = tester.widget<TextField>(find.byKey(const Key('prompt_input_field')));
      expect(inputField.controller?.text, 'Try this command');
    });

    testWidgets('handles pull-to-refresh on transcript', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: testTurns);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fakeRepo.getHistoryCalls, 1);

      // Pull down on transcript list view
      await tester.fling(
        find.byKey(const Key('transcript_list_view')),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fakeRepo.getHistoryCalls, greaterThanOrEqualTo(2));
    });

    testWidgets('renders empty state when session has no turns', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Start the conversation by sending a prompt below.'), findsOneWidget);
    });
  });
}
