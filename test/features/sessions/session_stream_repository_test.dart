import 'dart:async';

import 'package:compozy_app/core/network/sse_client.dart';
import 'package:compozy_app/features/sessions/data/session_stream_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session_stream_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStreamRepository (UT-018)', () {
    test('testSessionStreamRepository - emits typed stream events for session turns', () async {
      final requestedPaths = <String>[];
      final eventStreamController = StreamController<String>();
      final connectedCompleter = Completer<void>();

      final sseClient = SseClient(
        baseUrl: 'http://localhost:2123',
        streamProvider: (url, headers) async {
          requestedPaths.add(url);
          connectedCompleter.complete();
          return eventStreamController.stream;
        },
      );

      final repository = SessionStreamRepositoryImpl(
        sseClient: sseClient,
        workspaceResolver: (sessionId) {
          if (sessionId == 'sess_with_ws') return 'ws_compozy_main';
          return null;
        },
      );

      final receivedEvents = <SessionStreamEvent>[];
      final subscription = repository
          .watchSessionStream('sess_with_ws')
          .listen(receivedEvents.add);

      // Wait until connection is established before pumping events
      await connectedCompleter.future;

      // 1. Transcript snapshot event
      eventStreamController.add(
        'event: transcript_snapshot\n'
        'data: {"session_id": "sess_with_ws", "entries": ['
        '{"message": {"id": "turn_1", "role": "user", "parts": [{"type": "text", "text": "Check status"}]}},'
        '{"message": {"id": "turn_2", "role": "assistant", "parts": [{"type": "text", "text": "Running checks..."}]}}'
        ']}\n\n',
      );

      // 2. Live incoming text delta chunk (US-006.AC-1, US-006.AC-3)
      eventStreamController.add(
        'event: text_delta\n'
        'data: {"turn_id": "turn_3", "delta": "All systems operational", "session_id": "sess_with_ws"}\n\n',
      );

      // 3. Tool execution active state (US-006.AC-4, UT-017, UT-018)
      eventStreamController.add(
        'event: tool_call\n'
        'data: {"turn_id": "turn_3", "tool_name": "git_status", "status": "in_progress", "tool_call_id": "call_42", "input": {"verbose": true}}\n\n',
      );

      // 4. Tool execution settled/completed state
      eventStreamController.add(
        'event: tool_execution\n'
        'data: {"turn_id": "turn_3", "tool_name": "git_status", "status": "completed", "tool_call_id": "call_42", "output": "working tree clean"}\n\n',
      );

      // 5. Turn lifecycle completion event
      eventStreamController.add(
        'event: turn_complete\n'
        'data: {"turn_id": "turn_3", "status": "completed", "session_id": "sess_with_ws", "turn": {"turn_id": "turn_3", "user_message": "Check status", "agent_message": "All systems operational", "status": "completed", "tool_calls": ["git_status"]}}\n\n',
      );

      // 6. Session state transition
      eventStreamController.add(
        'event: session_state_changed\n'
        'data: {"session_id": "sess_with_ws", "state": "idle"}\n\n',
      );

      // Allow event loop to process all emissions
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedEvents.length, equals(6));

      // Assert 1: Transcript snapshot
      final snapshotEvent = receivedEvents[0];
      expect(snapshotEvent, isA<SessionTranscriptSnapshotEvent>());
      final typedSnapshot = snapshotEvent as SessionTranscriptSnapshotEvent;
      expect(typedSnapshot.turns.length, equals(2));
      expect(typedSnapshot.turns[0].userMessage, equals('Check status'));
      expect(typedSnapshot.turns[1].agentMessage, equals('Running checks...'));

      // Assert 2: Text delta
      final deltaEvent = receivedEvents[1];
      expect(deltaEvent, isA<SessionTextDeltaEvent>());
      final typedDelta = deltaEvent as SessionTextDeltaEvent;
      expect(typedDelta.textDelta, equals('All systems operational'));
      expect(typedDelta.turnId, equals('turn_3'));
      expect(typedDelta.sessionId, equals('sess_with_ws'));

      // Assert 3: Active tool execution
      final activeToolEvent = receivedEvents[2];
      expect(activeToolEvent, isA<SessionToolExecutionEvent>());
      final typedActiveTool = activeToolEvent as SessionToolExecutionEvent;
      expect(typedActiveTool.toolName, equals('git_status'));
      expect(typedActiveTool.status, equals('in_progress'));
      expect(typedActiveTool.toolCallId, equals('call_42'));
      expect(typedActiveTool.isActive, isTrue);
      expect(typedActiveTool.isCompleted, isFalse);

      // Assert 4: Completed tool execution
      final completedToolEvent = receivedEvents[3];
      expect(completedToolEvent, isA<SessionToolExecutionEvent>());
      final typedCompletedTool = completedToolEvent as SessionToolExecutionEvent;
      expect(typedCompletedTool.toolName, equals('git_status'));
      expect(typedCompletedTool.status, equals('completed'));
      expect(typedCompletedTool.isActive, isFalse);
      expect(typedCompletedTool.isCompleted, isTrue);
      expect(typedCompletedTool.output, equals('working tree clean'));

      // Assert 5: Turn completion
      final turnEvent = receivedEvents[4];
      expect(turnEvent, isA<SessionTurnEvent>());
      final typedTurn = turnEvent as SessionTurnEvent;
      expect(typedTurn.status, equals('completed'));
      expect(typedTurn.turnId, equals('turn_3'));
      expect(typedTurn.turn?.agentMessage, equals('All systems operational'));
      expect(typedTurn.turn?.toolCalls, contains('git_status'));

      // Assert 6: State change
      final stateEvent = receivedEvents[5];
      expect(stateEvent, isA<SessionStateChangedEvent>());
      final typedState = stateEvent as SessionStateChangedEvent;
      expect(typedState.state, equals('idle'));

      // Verify workspace-scoped URL construction
      expect(
        requestedPaths.first,
        equals('http://localhost:2123/api/workspaces/ws_compozy_main/sessions/sess_with_ws/stream'),
      );

      await subscription.cancel();
      await eventStreamController.close();
    });

    test('resolves default session stream path when workspace is not specified', () async {
      final requestedPaths = <String>[];
      final eventStreamController = StreamController<String>();

      final sseClient = SseClient(
        baseUrl: 'http://localhost:2123',
        streamProvider: (url, headers) async {
          requestedPaths.add(url);
          return eventStreamController.stream;
        },
      );

      final repository = SessionStreamRepositoryImpl(sseClient: sseClient);
      final subscription = repository.getSessionStream('sess_default').listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        requestedPaths.first,
        equals('http://localhost:2123/api/sessions/sess_default/stream'),
      );

      await subscription.cancel();
      await eventStreamController.close();
    });

    test('watches global daemon events via /events', () async {
      final requestedPaths = <String>[];
      final eventStreamController = StreamController<String>();

      final sseClient = SseClient(
        baseUrl: 'http://localhost:2123',
        streamProvider: (url, headers) async {
          requestedPaths.add(url);
          return eventStreamController.stream;
        },
      );

      final repository = SessionStreamRepositoryImpl(sseClient: sseClient);
      final subscription = repository.watchGlobalEvents().listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        requestedPaths.first,
        equals('http://localhost:2123/events'),
      );

      await subscription.cancel();
      await eventStreamController.close();
    });

    test('Riverpod sessionStreamProvider emits stream events for specific session', () async {
      final eventStreamController = StreamController<String>();
      final connectedCompleter = Completer<void>();

      final sseClient = SseClient(
        baseUrl: 'http://localhost:2123',
        streamProvider: (url, headers) async {
          connectedCompleter.complete();
          return eventStreamController.stream;
        },
      );

      final container = ProviderContainer(
        overrides: [
          sessionStreamRepositoryProvider.overrideWithValue(
            SessionStreamRepositoryImpl(sseClient: sseClient),
          ),
        ],
      );

      final receivedAsync = <AsyncValue<SessionStreamEvent>>[];
      final subscription = container.listen(
        sessionStreamProvider('sess_riverpod_test'),
        (previous, next) => receivedAsync.add(next),
        fireImmediately: true,
      );

      expect(receivedAsync.length, equals(1));
      expect(receivedAsync.first, isA<AsyncLoading>());

      await connectedCompleter.future;

      eventStreamController.add(
        'event: text_delta\ndata: {"turn_id": "t1", "delta": "Provider stream active"}\n\n',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedAsync.length, equals(2));
      final dataValue = receivedAsync.last.value;
      expect(dataValue, isA<SessionTextDeltaEvent>());
      expect((dataValue as SessionTextDeltaEvent).textDelta, equals('Provider stream active'));

      subscription.close();
      container.dispose();
      await eventStreamController.close();
    });
  });
}
