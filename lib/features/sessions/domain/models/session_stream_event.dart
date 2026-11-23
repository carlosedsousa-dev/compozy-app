import 'package:flutter/foundation.dart';

import '../../../../core/network/sse_client.dart';
import 'turn.dart';

/// Base class representing a typed event emitted over the CompozyOS session SSE stream.
@immutable
sealed class SessionStreamEvent {
  final String eventType;
  final String? sessionId;
  final String? turnId;
  final dynamic rawData;

  const SessionStreamEvent({
    required this.eventType,
    this.sessionId,
    this.turnId,
    this.rawData,
  });

  /// Factory constructor to parse an [SseEvent] into a typed [SessionStreamEvent].
  factory SessionStreamEvent.fromSseEvent(
    SseEvent sseEvent, {
    String? defaultSessionId,
  }) {
    final eventType = sseEvent.event;
    final json = sseEvent.jsonMap;
    final sessionId = json?['session_id']?.toString() ??
        json?['sessionId']?.toString() ??
        defaultSessionId;
    final turnId = json?['turn_id']?.toString() ??
        json?['turnId']?.toString();

    // 1. Transcript snapshot
    if (eventType == 'transcript_snapshot' || json?['type'] == 'transcript_snapshot') {
      final entries = json?['entries'] as List<dynamic>?;
      final turns = <Turn>[];
      if (entries != null) {
        for (final entry in entries) {
          if (entry is Map<String, dynamic>) {
            final message = entry['message'] as Map<String, dynamic>?;
            if (message != null) {
              final tId = message['id']?.toString() ??
                  entry['sequence']?.toString() ??
                  '';
              final role = message['role']?.toString();
              final parts = message['parts'] as List<dynamic>?;
              String? text;
              final tools = <String>[];
              if (parts != null) {
                for (final p in parts) {
                  if (p is Map<String, dynamic>) {
                    if (p['type'] == 'text') {
                      text = p['text']?.toString();
                    } else if (p['type'] == 'data-compozy-event') {
                      final data = p['data'] as Map<String, dynamic>?;
                      if (data != null && data['type'] == 'tool_call') {
                        final tName = data['title']?.toString() ??
                            data['tool']?.toString();
                        if (tName != null) tools.add(tName);
                      }
                    } else if (p['type'] is String &&
                        (p['type'] as String).startsWith('tool-')) {
                      final tName = (p['type'] as String).substring(5);
                      tools.add(tName);
                    }
                  }
                }
              }
              if (role == 'user') {
                turns.add(Turn(
                  turnId: tId,
                  userMessage: text,
                  status: 'completed',
                  toolCalls: tools,
                ));
              } else {
                turns.add(Turn(
                  turnId: tId,
                  agentMessage: text,
                  status: 'completed',
                  toolCalls: tools,
                ));
              }
            }
          }
        }
      }
      return SessionTranscriptSnapshotEvent(
        sessionId: sessionId,
        turns: turns,
        rawData: json,
      );
    }

    // 2. Tool execution / tool call
    if (eventType == 'tool_call' ||
        eventType == 'tool_execution' ||
        eventType == 'tool_progress' ||
        json?['type'] == 'tool_call' ||
        json?['type'] == 'tool_execution' ||
        json?['tool_name'] != null ||
        json?['tool'] != null) {
      final toolName = json?['tool_name']?.toString() ??
          json?['tool']?.toString() ??
          json?['name']?.toString() ??
          '';
      final status = json?['status']?.toString() ?? 'in_progress';
      final toolCallId = json?['tool_call_id']?.toString() ??
          json?['toolCallId']?.toString() ??
          json?['id']?.toString();
      return SessionToolExecutionEvent(
        toolName: toolName,
        status: status,
        toolCallId: toolCallId,
        turnId: turnId,
        sessionId: sessionId,
        input: json?['input'] ?? json?['arguments'] ?? json?['args'],
        output: json?['output'] ?? json?['result'],
        rawData: json ?? {'raw': sseEvent.data},
      );
    }

    // 3. Text delta / message delta / token
    if (eventType == 'text_delta' ||
        eventType == 'message_delta' ||
        eventType == 'chunk' ||
        eventType == 'token' ||
        json?['type'] == 'text_delta' ||
        json?['type'] == 'message_delta' ||
        json?['delta'] != null) {
      final delta = json?['delta']?.toString() ??
          json?['text']?.toString() ??
          json?['chunk']?.toString() ??
          (json == null ? sseEvent.data : '');
      return SessionTextDeltaEvent(
        textDelta: delta,
        turnId: turnId,
        sessionId: sessionId,
        messageId: json?['message_id']?.toString() ??
            json?['messageId']?.toString(),
        rawData: json ?? {'raw': sseEvent.data},
      );
    }

    // 4. Turn events (turn_start, turn_complete, etc.)
    if (eventType == 'turn_start' ||
        eventType == 'turn_complete' ||
        eventType == 'turn_completed' ||
        eventType == 'turn' ||
        json?['type'] == 'turn_start' ||
        json?['type'] == 'turn_complete') {
      final status = json?['status']?.toString() ??
          (eventType == 'turn_start' ? 'started' : 'completed');
      Turn? turn;
      if (json != null && json.containsKey('turn')) {
        final rawTurn = json['turn'];
        if (rawTurn is Map<String, dynamic>) {
          turn = _parseTurn(rawTurn);
        }
      }
      return SessionTurnEvent(
        status: status,
        turnId: turnId,
        sessionId: sessionId,
        turn: turn,
        userMessage: json?['user_message']?.toString(),
        agentMessage: json?['agent_message']?.toString(),
        rawData: json,
      );
    }

    // 5. Session state changed
    if (eventType == 'session_state_changed' ||
        eventType == 'state_changed' ||
        json?['type'] == 'session_state_changed') {
      final state = json?['state']?.toString() ??
          json?['status']?.toString() ??
          '';
      return SessionStateChangedEvent(
        state: state,
        sessionId: sessionId,
        rawData: json,
      );
    }

    // 6. Plain message event
    if (eventType == 'message' && json == null && sseEvent.data.isNotEmpty) {
      return SessionTextDeltaEvent(
        textDelta: sseEvent.data,
        sessionId: sessionId,
        rawData: {'raw': sseEvent.data},
      );
    }

    // 7. Generic / Unknown event
    return SessionUnknownEvent(
      eventType: eventType,
      sessionId: sessionId,
      turnId: turnId,
      rawData: json ?? {'raw': sseEvent.data},
    );
  }

  static Turn _parseTurn(Map<String, dynamic> json) {
    final turnId = json['turnId']?.toString() ??
        json['turn_id']?.toString() ??
        '';
    final userMessage = json['userMessage']?.toString() ??
        json['user_message']?.toString();
    final agentMessage = json['agentMessage']?.toString() ??
        json['agent_message']?.toString();
    final status = json['status']?.toString() ?? 'completed';
    final tools = <String>[];
    final rawTools = json['toolCalls'] ?? json['tool_calls'];
    if (rawTools is List) {
      for (final item in rawTools) {
        if (item != null) tools.add(item.toString());
      }
    }
    return Turn(
      turnId: turnId,
      userMessage: userMessage,
      agentMessage: agentMessage,
      status: status,
      toolCalls: tools,
    );
  }
}

/// Event emitted when assistant text is streamed in real time.
class SessionTextDeltaEvent extends SessionStreamEvent {
  final String textDelta;
  final String? messageId;

  const SessionTextDeltaEvent({
    required this.textDelta,
    super.turnId,
    super.sessionId,
    this.messageId,
    super.rawData,
  }) : super(eventType: 'text_delta');

  @override
  String toString() =>
      'SessionTextDeltaEvent(textDelta: $textDelta, turnId: $turnId, sessionId: $sessionId)';
}

/// Event emitted during tool execution (started, progressing, or completed).
class SessionToolExecutionEvent extends SessionStreamEvent {
  final String toolName;
  final String status;
  final String? toolCallId;
  final dynamic input;
  final dynamic output;

  const SessionToolExecutionEvent({
    required this.toolName,
    required this.status,
    this.toolCallId,
    super.turnId,
    super.sessionId,
    this.input,
    this.output,
    super.rawData,
  }) : super(eventType: 'tool_execution');

  /// Whether the tool execution is currently active or in-progress.
  bool get isActive =>
      status == 'active' || status == 'in_progress' || status == 'running';

  /// Whether the tool execution has settled/completed.
  bool get isCompleted =>
      status == 'completed' ||
      status == 'settled' ||
      status == 'done' ||
      status == 'success';

  @override
  String toString() =>
      'SessionToolExecutionEvent(tool: $toolName, status: $status, callId: $toolCallId)';
}

/// Event emitted when a turn lifecycle changes (started, busy, completed).
class SessionTurnEvent extends SessionStreamEvent {
  final String status;
  final Turn? turn;
  final String? userMessage;
  final String? agentMessage;

  const SessionTurnEvent({
    required this.status,
    this.turn,
    this.userMessage,
    this.agentMessage,
    super.turnId,
    super.sessionId,
    super.rawData,
  }) : super(eventType: 'turn');

  @override
  String toString() =>
      'SessionTurnEvent(status: $status, turnId: $turnId, sessionId: $sessionId)';
}

/// Event carrying the snapshot of session transcript turns.
class SessionTranscriptSnapshotEvent extends SessionStreamEvent {
  final List<Turn> turns;

  const SessionTranscriptSnapshotEvent({
    required this.turns,
    super.sessionId,
    super.rawData,
  }) : super(eventType: 'transcript_snapshot');

  @override
  String toString() =>
      'SessionTranscriptSnapshotEvent(turnsCount: ${turns.length}, sessionId: $sessionId)';
}

/// Event emitted when the session's overall state changes (e.g. idle, active, busy, stopped).
class SessionStateChangedEvent extends SessionStreamEvent {
  final String state;

  const SessionStateChangedEvent({
    required this.state,
    super.sessionId,
    super.rawData,
  }) : super(eventType: 'session_state_changed');

  @override
  String toString() =>
      'SessionStateChangedEvent(state: $state, sessionId: $sessionId)';
}

/// Generic fallback event for unrecognized or custom event types.
class SessionUnknownEvent extends SessionStreamEvent {
  const SessionUnknownEvent({
    required super.eventType,
    super.sessionId,
    super.turnId,
    super.rawData,
  });

  @override
  String toString() =>
      'SessionUnknownEvent(eventType: $eventType, sessionId: $sessionId, rawData: $rawData)';
}
