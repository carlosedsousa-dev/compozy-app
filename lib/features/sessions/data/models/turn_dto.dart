import '../../domain/models/turn.dart';

/// Data Transfer Object for serializing/deserializing conversation turns.
class TurnDto {
  final String turnId;
  final String? userMessage;
  final String? agentMessage;
  final String status;
  final List<String> toolCalls;

  const TurnDto({
    required this.turnId,
    this.userMessage,
    this.agentMessage,
    required this.status,
    this.toolCalls = const [],
  });

  factory TurnDto.fromJson(Map<String, dynamic> json) {
    final turnId = json['turnId']?.toString() ??
        json['turn_id']?.toString() ??
        '';

    String? userMsg = json['userMessage']?.toString() ??
        json['user_message']?.toString();
    String? agentMsg = json['agentMessage']?.toString() ??
        json['agent_message']?.toString();

    final status = json['status']?.toString() ?? 'completed';

    final toolCallsList = <String>[];
    final rawTools = json['toolCalls'] ?? json['tool_calls'];
    if (rawTools is List) {
      for (final item in rawTools) {
        if (item != null) {
          toolCallsList.add(item.toString());
        }
      }
    }

    // Support event-based payload (TurnHistoryPayload with events list)
    final events = json['events'];
    if (events is List) {
      for (final evt in events) {
        if (evt is Map<String, dynamic>) {
          final actorKind = evt['actor_kind']?.toString();
          final content = evt['content'];
          if (actorKind == 'user') {
            userMsg ??= content is String
                ? content
                : (content is Map ? content['text']?.toString() : null);
          } else if (actorKind == 'agent' || actorKind == 'assistant') {
            agentMsg ??= content is String
                ? content
                : (content is Map ? content['text']?.toString() : null);
          }

          final toolName = evt['tool_name']?.toString() ??
              (content is Map ? content['tool_name']?.toString() : null);
          if (toolName != null &&
              toolName.isNotEmpty &&
              !toolCallsList.contains(toolName)) {
            toolCallsList.add(toolName);
          }
        }
      }
    }

    return TurnDto(
      turnId: turnId,
      userMessage: userMsg,
      agentMessage: agentMsg,
      status: status,
      toolCalls: toolCallsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'turn_id': turnId,
      if (userMessage != null) 'user_message': userMessage,
      if (agentMessage != null) 'agent_message': agentMessage,
      'status': status,
      'tool_calls': toolCalls,
    };
  }

  Turn toDomain() {
    return Turn(
      turnId: turnId,
      userMessage: userMessage,
      agentMessage: agentMessage,
      status: status,
      toolCalls: toolCalls,
    );
  }
}
