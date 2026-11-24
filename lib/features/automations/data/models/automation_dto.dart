import '../../domain/models/automation_job.dart';
import '../../domain/models/automation_run.dart';
import '../../domain/models/automation_trigger.dart';

class AutomationJobDto {
  final String id;
  final String name;
  final String agentName;
  final String prompt;
  final bool enabled;
  final String scope;
  final String? workspaceId;
  final String targetKind;
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

  const AutomationJobDto({
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

  factory AutomationJobDto.fromJson(Map<String, dynamic> json) {
    return AutomationJobDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Automation',
      agentName: json['agent_name']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      enabled: json['enabled'] != false, // defaults to true
      scope: json['scope']?.toString() ?? 'workspace',
      workspaceId: json['workspace_id']?.toString(),
      targetKind: json['target_kind']?.toString() ?? 'agent',
      loopTarget: json['loop_target'] is Map
          ? LoopTargetConfig.fromJson(Map<String, dynamic>.from(json['loop_target'] as Map))
          : null,
      task: json['task'] is Map
          ? JobTaskConfig.fromJson(Map<String, dynamic>.from(json['task'] as Map))
          : null,
      endpointSlug: json['endpoint_slug']?.toString(),
      webhookId: json['webhook_id']?.toString(),
      targetInstanceScope: json['target_instance_scope']?.toString(),
      schedule: json['schedule'] is Map
          ? ScheduleSpec.fromJson(Map<String, dynamic>.from(json['schedule'] as Map))
          : null,
      retry: json['retry'] is Map
          ? RetryConfig.fromJson(Map<String, dynamic>.from(json['retry'] as Map))
          : const RetryConfig(),
      fireLimit: json['fire_limit'] is Map
          ? FireLimitConfig.fromJson(Map<String, dynamic>.from(json['fire_limit'] as Map))
          : const FireLimitConfig(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      lastRun: json['last_run'] is Map
          ? AutomationLastRun.fromJson(Map<String, dynamic>.from(json['last_run'] as Map))
          : null,
    );
  }

  AutomationJob toDomain() {
    return AutomationJob(
      id: id,
      name: name,
      agentName: agentName,
      prompt: prompt,
      enabled: enabled,
      scope: scope,
      workspaceId: workspaceId,
      targetKind: targetKind,
      loopTarget: loopTarget,
      task: task,
      endpointSlug: endpointSlug,
      webhookId: webhookId,
      targetInstanceScope: targetInstanceScope,
      schedule: schedule,
      retry: retry,
      fireLimit: fireLimit,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastRun: lastRun,
    );
  }
}

class AutomationRunDto {
  final String id;
  final String? jobId;
  final String? triggerId;
  final String? sessionId;
  final String status;
  final int attempt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? error;
  final String? skipReason;
  final Map<String, dynamic> metadata;

  const AutomationRunDto({
    required this.id,
    this.jobId,
    this.triggerId,
    this.sessionId,
    required this.status,
    this.attempt = 1,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.error,
    this.skipReason,
    this.metadata = const {},
  });

  factory AutomationRunDto.fromJson(Map<String, dynamic> json) {
    return AutomationRunDto(
      id: json['id']?.toString() ?? '',
      jobId: json['job_id']?.toString(),
      triggerId: json['trigger_id']?.toString(),
      sessionId: json['session_id']?.toString(),
      status: json['status']?.toString().toLowerCase() ?? 'scheduled',
      attempt: json['attempt'] is num ? (json['attempt'] as num).toInt() : 1,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      error: json['error']?.toString() ?? json['delivery_error']?.toString(),
      skipReason: json['skip_reason']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  AutomationRun toDomain() {
    return AutomationRun(
      id: id,
      jobId: jobId,
      triggerId: triggerId,
      sessionId: sessionId,
      status: status,
      attempt: attempt,
      scheduledAt: scheduledAt,
      startedAt: startedAt,
      endedAt: endedAt,
      error: error,
      skipReason: skipReason,
      metadata: metadata,
    );
  }
}

class AutomationTriggerDto {
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

  const AutomationTriggerDto({
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

  factory AutomationTriggerDto.fromJson(Map<String, dynamic> json) {
    Map<String, String> filterMap = const {};
    if (json['filter'] is Map) {
      filterMap = (json['filter'] as Map).map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }

    return AutomationTriggerDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled Trigger',
      agentName: json['agent_name']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
      event: json['event']?.toString() ?? '',
      filter: filterMap,
      targetKind: json['target_kind']?.toString() ?? 'agent',
      loopTarget: json['loop_target'] is Map
          ? LoopTargetConfig.fromJson(Map<String, dynamic>.from(json['loop_target'] as Map))
          : null,
      enabled: json['enabled'] != false,
      retry: json['retry'] is Map
          ? RetryConfig.fromJson(Map<String, dynamic>.from(json['retry'] as Map))
          : const RetryConfig(),
      fireLimit: json['fire_limit'] is Map
          ? FireLimitConfig.fromJson(Map<String, dynamic>.from(json['fire_limit'] as Map))
          : const FireLimitConfig(),
      endpointSlug: json['endpoint_slug']?.toString(),
      webhookId: json['webhook_id']?.toString(),
      webhookSecretPresent: json['webhook_secret_present'] == true,
      webhookSecretHash: json['webhook_secret_hash']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      lastRun: json['last_run'] is Map
          ? AutomationLastRun.fromJson(Map<String, dynamic>.from(json['last_run'] as Map))
          : null,
    );
  }

  AutomationTrigger toDomain() {
    return AutomationTrigger(
      id: id,
      name: name,
      agentName: agentName,
      prompt: prompt,
      event: event,
      filter: filter,
      targetKind: targetKind,
      loopTarget: loopTarget,
      enabled: enabled,
      retry: retry,
      fireLimit: fireLimit,
      endpointSlug: endpointSlug,
      webhookId: webhookId,
      webhookSecretPresent: webhookSecretPresent,
      webhookSecretHash: webhookSecretHash,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastRun: lastRun,
    );
  }
}
