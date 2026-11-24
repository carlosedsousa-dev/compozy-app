import 'package:flutter/foundation.dart';

import 'agent_definition.dart';

export 'agent_definition.dart';

/// Semantic presence state of an agent derived from session catalog.
enum AgentPresenceStatus {
  working,
  needsYou,
  idle,
}

/// Joined presence view combining static agent definition with live session state.
@immutable
class AgentPresence {
  final AgentDefinition agent;
  final AgentPresenceStatus status;
  final int workingSessionsCount;
  final int waitingSessionsCount;
  final int totalSessionsCount;

  const AgentPresence({
    required this.agent,
    required this.status,
    this.workingSessionsCount = 0,
    this.waitingSessionsCount = 0,
    this.totalSessionsCount = 0,
  });

  bool get isWorking => status == AgentPresenceStatus.working;
  bool get isNeedsYou => status == AgentPresenceStatus.needsYou;
  bool get isIdle => status == AgentPresenceStatus.idle;

  AgentPresence copyWith({
    AgentDefinition? agent,
    AgentPresenceStatus? status,
    int? workingSessionsCount,
    int? waitingSessionsCount,
    int? totalSessionsCount,
  }) {
    return AgentPresence(
      agent: agent ?? this.agent,
      status: status ?? this.status,
      workingSessionsCount: workingSessionsCount ?? this.workingSessionsCount,
      waitingSessionsCount: waitingSessionsCount ?? this.waitingSessionsCount,
      totalSessionsCount: totalSessionsCount ?? this.totalSessionsCount,
    );
  }
}
