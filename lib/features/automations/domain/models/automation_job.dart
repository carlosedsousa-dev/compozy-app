import 'package:flutter/foundation.dart';

import 'automation_run.dart';

@immutable
class ScheduleSpec {
  final String mode; // e.g. 'cron'
  final String expr; // e.g. '0 9 * * *'
  final String? catchUpPolicy;

  const ScheduleSpec({
    this.mode = 'cron',
    required this.expr,
    this.catchUpPolicy,
  });

  factory ScheduleSpec.fromJson(Map<String, dynamic> json) {
    return ScheduleSpec(
      mode: json['mode']?.toString() ?? 'cron',
      expr: json['expr']?.toString() ?? '',
      catchUpPolicy: json['catch_up_policy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'expr': expr,
        if (catchUpPolicy != null) 'catch_up_policy': catchUpPolicy,
      };
}

@immutable
class RetryConfig {
  final String strategy; // 'none' | 'backoff'
  final int maxRetries;
  final String baseDelay;

  const RetryConfig({
    this.strategy = 'none',
    this.maxRetries = 0,
    this.baseDelay = '',
  });

  factory RetryConfig.fromJson(Map<String, dynamic> json) {
    return RetryConfig(
      strategy: json['strategy']?.toString() ?? 'none',
      maxRetries: json['max_retries'] is num ? (json['max_retries'] as num).toInt() : 0,
      baseDelay: json['base_delay']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'strategy': strategy,
        'max_retries': maxRetries,
        'base_delay': baseDelay,
      };

  String get displayDescription {
    if (strategy.toLowerCase() == 'backoff' && maxRetries > 0) {
      final delayStr = baseDelay.isNotEmpty ? ' ($baseDelay base)' : '';
      return 'Backoff, up to $maxRetries retries$delayStr';
    }
    return 'None';
  }
}

@immutable
class FireLimitConfig {
  final int max;
  final String window;

  const FireLimitConfig({
    this.max = 0,
    this.window = '',
  });

  factory FireLimitConfig.fromJson(Map<String, dynamic> json) {
    return FireLimitConfig(
      max: json['max'] is num ? (json['max'] as num).toInt() : 0,
      window: json['window']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'max': max,
        'window': window,
      };

  String get displayDescription {
    if (max > 0) {
      final winStr = window.isNotEmpty ? ' / $window' : '';
      return 'Max $max runs$winStr';
    }
    return 'Unlimited';
  }
}

@immutable
class LoopTargetConfig {
  final String loopName;
  final String? workspaceId;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> inputMapping;

  const LoopTargetConfig({
    required this.loopName,
    this.workspaceId,
    this.inputs = const {},
    this.inputMapping = const {},
  });

  factory LoopTargetConfig.fromJson(Map<String, dynamic> json) {
    return LoopTargetConfig(
      loopName: json['loop_name']?.toString() ?? '',
      workspaceId: json['workspace_id']?.toString(),
      inputs: json['inputs'] is Map
          ? Map<String, dynamic>.from(json['inputs'] as Map)
          : const {},
      inputMapping: json['input_mapping'] is Map
          ? Map<String, dynamic>.from(json['input_mapping'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'loop_name': loopName,
        if (workspaceId != null) 'workspace_id': workspaceId,
        if (inputs.isNotEmpty) 'inputs': inputs,
        if (inputMapping.isNotEmpty) 'input_mapping': inputMapping,
      };
}

@immutable
class JobTaskConfig {
  final String? prompt;
  final String? agentName;
  final Map<String, dynamic> inputs;

  const JobTaskConfig({
    this.prompt,
    this.agentName,
    this.inputs = const {},
  });

  factory JobTaskConfig.fromJson(Map<String, dynamic> json) {
    return JobTaskConfig(
      prompt: json['prompt']?.toString(),
      agentName: json['agent_name']?.toString(),
      inputs: json['inputs'] is Map
          ? Map<String, dynamic>.from(json['inputs'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        if (prompt != null) 'prompt': prompt,
        if (agentName != null) 'agent_name': agentName,
        if (inputs.isNotEmpty) 'inputs': inputs,
      };
}

@immutable
class AutomationJob {
  final String id;
  final String name;
  final String agentName;
  final String prompt;
  final bool enabled;
  final String scope; // 'workspace' | 'global'
  final String? workspaceId;
  final String targetKind; // 'agent' | 'loop' | 'agent_instance'
  final LoopTargetConfig? loopTarget;
  final JobTaskConfig? task;
  final String? endpointSlug;
  final String? webhookId;
  final String? targetInstanceScope;
  final ScheduleSpec? schedule;
  final RetryConfig retry;
  final FireLimitConfig fireLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AutomationLastRun? lastRun;

  const AutomationJob({
    required this.id,
    required this.name,
    this.agentName = '',
    this.prompt = '',
    this.enabled = true,
    this.scope = 'workspace',
    this.workspaceId,
    this.targetKind = 'agent',
    this.loopTarget,
    this.task,
    this.endpointSlug,
    this.webhookId,
    this.targetInstanceScope,
    this.schedule,
    this.retry = const RetryConfig(),
    this.fireLimit = const FireLimitConfig(),
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

  /// True if the target is a loop.
  bool get isLoopTarget => targetKind.toLowerCase() == 'loop';
}
