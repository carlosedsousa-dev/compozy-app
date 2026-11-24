import 'package:flutter/foundation.dart';

import 'automation_job.dart';
import 'automation_run.dart';

@immutable
class AutomationTrigger {
  final String id;
  final String name;
  final String agentName;
  final String prompt;
  final String event;
  final Map<String, String> filter;
  final String targetKind;
  final LoopTargetConfig? loopTarget;
  final bool enabled;
  final RetryConfig retry;
  final FireLimitConfig fireLimit;
  final String? endpointSlug;
  final String? webhookId;
  final bool webhookSecretPresent;
  final String? webhookSecretHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AutomationLastRun? lastRun;

  const AutomationTrigger({
    required this.id,
    required this.name,
    this.agentName = '',
    this.prompt = '',
    this.event = '',
    this.filter = const {},
    this.targetKind = 'agent',
    this.loopTarget,
    this.enabled = true,
    this.retry = const RetryConfig(),
    this.fireLimit = const FireLimitConfig(),
    this.endpointSlug,
    this.webhookId,
    this.webhookSecretPresent = false,
    this.webhookSecretHash,
    this.createdAt,
    this.updatedAt,
    this.lastRun,
  });

  /// Target display pill text, e.g. "Loop: council" or "Agent: dispatcher".
  String get targetDisplay {
    if (targetKind.toLowerCase() == 'loop' && loopTarget != null && loopTarget!.loopName.isNotEmpty) {
      return 'Loop: ${loopTarget!.loopName}';
    }
    if (agentName.isNotEmpty) {
      return 'Agent: $agentName';
    }
    return targetKind.toUpperCase();
  }
}
