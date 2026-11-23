import 'package:flutter/foundation.dart';

/// Domain entity representing a conversation turn in a CompozyOS session.
@immutable
class Turn {
  final String turnId;
  final String? userMessage;
  final String? agentMessage;
  final String status;
  final List<String> toolCalls;

  const Turn({
    required this.turnId,
    this.userMessage,
    this.agentMessage,
    required this.status,
    this.toolCalls = const [],
  });

  Turn copyWith({
    String? turnId,
    String? userMessage,
    String? agentMessage,
    String? status,
    List<String>? toolCalls,
  }) {
    return Turn(
      turnId: turnId ?? this.turnId,
      userMessage: userMessage ?? this.userMessage,
      agentMessage: agentMessage ?? this.agentMessage,
      status: status ?? this.status,
      toolCalls: toolCalls ?? this.toolCalls,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Turn &&
          runtimeType == other.runtimeType &&
          turnId == other.turnId &&
          userMessage == other.userMessage &&
          agentMessage == other.agentMessage &&
          status == other.status &&
          listEquals(toolCalls, other.toolCalls);

  @override
  int get hashCode =>
      turnId.hashCode ^
      userMessage.hashCode ^
      agentMessage.hashCode ^
      status.hashCode ^
      Object.hashAll(toolCalls);

  @override
  String toString() {
    return 'Turn(turnId: $turnId, userMessage: $userMessage, agentMessage: $agentMessage, status: $status, toolCalls: $toolCalls)';
  }
}
