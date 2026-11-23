import 'dart:async';

import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/domain/repositories/session_repository.dart';
import 'package:compozy_app/features/sessions/presentation/session_chat_screen.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/chat_bubble.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/tool_execution_pill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeSessionRepository implements SessionRepository {
  List<Turn> turns = [];

  _FakeSessionRepository({List<Turn>? initialTurns})
      : turns = initialTurns ?? [];

  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async => [];

  @override
  Future<Session> getSession(String sessionId) async => throw UnimplementedError();

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async => turns;

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
  final testSession = Session(
    id: 'sess-stream-test',
    name: 'Streaming Test Session',
    agent: 'designer',
    state: 'active',
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    updatedAt: DateTime.now(),
  );

  group('testLiveChatStreaming (IT-006)', () {
    testWidgets('renders live text deltas and tool pills without manual refresh (US-006.AC-3, US-006.AC-4)', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: [
        const Turn(
          turnId: 'turn-existing-1',
          userMessage: 'What is the current status?',
          agentMessage: 'Analyzing current status...',
          status: 'completed',
          toolCalls: [],
        ),
      ]);

      final streamController = StreamController<SessionStreamEvent>.broadcast();
      addTearDown(() => streamController.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
            sessionStreamProvider(testSession.id).overrideWith((ref) => streamController.stream),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify existing turn is present
      expect(find.text('What is the current status?'), findsOneWidget);
      expect(find.text('Analyzing current status...'), findsOneWidget);

      // Verify no live tool execution or streaming bubble before stream emits
      expect(find.byType(ToolExecutionPill), findsNothing);
      expect(find.byKey(const Key('streaming_agent_bubble')), findsNothing);

      // -----------------------------------------------------------------------
      // 1. Emit active tool execution event (US-006.AC-4)
      // -----------------------------------------------------------------------
      streamController.add(
        const SessionToolExecutionEvent(
          toolName: 'compozy__tool_search',
          status: 'in_progress',
          toolCallId: 'tool_call_01',
          sessionId: 'sess-stream-test',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // ToolExecutionPill is rendered in chat flow showing active state
      expect(find.byType(ToolExecutionPill), findsOneWidget);
      expect(find.text('tool: compozy__tool_search'), findsOneWidget);
      expect(find.byKey(const Key('tool_pill_spinner')), findsOneWidget);
      expect(find.byKey(const Key('tool_pill_active_dot')), findsOneWidget);

      // -----------------------------------------------------------------------
      // 2. Stream incoming text deltas (US-006.AC-3)
      // -----------------------------------------------------------------------
      streamController.add(
        const SessionTextDeltaEvent(
          textDelta: 'Found 12 relevant ',
          sessionId: 'sess-stream-test',
          turnId: 'turn-live-1',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Streaming bubble is rendered with text delta and typing indicator
      expect(find.byKey(const Key('streaming_agent_bubble')), findsOneWidget);
      expect(find.textContaining('Found 12 relevant'), findsOneWidget);
      expect(find.byKey(const Key('streaming_typing_cursor')), findsOneWidget);
      expect(find.byType(PulsingCursor), findsOneWidget);

      // Stream next token chunk
      streamController.add(
        const SessionTextDeltaEvent(
          textDelta: 'design tokens.',
          sessionId: 'sess-stream-test',
          turnId: 'turn-live-1',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Text delta is appended without requiring manual screen refresh
      expect(find.textContaining('Found 12 relevant design tokens.'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 3. Settle tool execution to completed
      // -----------------------------------------------------------------------
      streamController.add(
        const SessionToolExecutionEvent(
          toolName: 'compozy__tool_search',
          status: 'completed',
          toolCallId: 'tool_call_01',
          sessionId: 'sess-stream-test',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tool execution pill transitions to settled state with checkmark
      expect(find.byKey(const Key('tool_pill_check_icon')), findsOneWidget);
      expect(find.byKey(const Key('tool_pill_spinner')), findsNothing);

      // -----------------------------------------------------------------------
      // 4. Turn completion event finalizes streaming turn
      // -----------------------------------------------------------------------
      streamController.add(
        const SessionTurnEvent(
          status: 'completed',
          turnId: 'turn-live-1',
          sessionId: 'sess-stream-test',
          agentMessage: 'Found 12 relevant design tokens.',
        ),
      );

      await tester.pumpAndSettle();

      // Streaming bubble transitions into settled turn in transcript
      expect(find.textContaining('Found 12 relevant design tokens.'), findsOneWidget);
      expect(find.byKey(const Key('streaming_agent_bubble')), findsNothing);
    });

    testWidgets('updates session state badge when session_state_changed event arrives', (tester) async {
      final fakeRepo = _FakeSessionRepository();
      final streamController = StreamController<SessionStreamEvent>.broadcast();
      addTearDown(() => streamController.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
            sessionStreamProvider(testSession.id).overrideWith((ref) => streamController.stream),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state is active
      expect(find.text('active'), findsOneWidget);

      // Emit state changed event to 'busy'
      streamController.add(
        const SessionStateChangedEvent(
          state: 'busy',
          sessionId: 'sess-stream-test',
        ),
      );

      await tester.pumpAndSettle();

      // App bar badge updates to busy
      expect(find.text('busy'), findsOneWidget);

      // Guidance banner appears when busy
      expect(find.text('Session is currently busy running a turn.'), findsOneWidget);
    });

    testWidgets('updates transcript turns when transcript_snapshot event arrives', (tester) async {
      final fakeRepo = _FakeSessionRepository(initialTurns: const []);
      final streamController = StreamController<SessionStreamEvent>.broadcast();
      addTearDown(() => streamController.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(fakeRepo),
            sessionStreamProvider(testSession.id).overrideWith((ref) => streamController.stream),
          ],
          child: MaterialApp(
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state is empty
      expect(find.text('No messages yet'), findsOneWidget);

      // Emit transcript snapshot
      streamController.add(
        const SessionTranscriptSnapshotEvent(
          sessionId: 'sess-stream-test',
          turns: [
            Turn(
              turnId: 'snap-1',
              userMessage: 'Loaded from snapshot',
              agentMessage: 'Snapshot processed successfully.',
              status: 'completed',
              toolCalls: ['read_file'],
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Transcript reflects snapshot turns immediately
      expect(find.text('No messages yet'), findsNothing);
      expect(find.text('Loaded from snapshot'), findsOneWidget);
      expect(find.text('Snapshot processed successfully.'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);
    });
  });
}
