import 'package:flutter/foundation.dart';

@immutable
class SchedulerCounters {
  final int cycles;
  final int wakeAttempts;
  final int wakeSkipped;
  final int wakeSucceeded;
  final int wakeFailed;
  final int capacityWaitingRuns;
  final int spawnRequested;
  final int needsAttention;
  final DateTime? lastCycleAt;

  const SchedulerCounters({
    this.cycles = 0,
    this.wakeAttempts = 0,
    this.wakeSkipped = 0,
    this.wakeSucceeded = 0,
    this.wakeFailed = 0,
    this.capacityWaitingRuns = 0,
    this.spawnRequested = 0,
    this.needsAttention = 0,
    this.lastCycleAt,
  });

  factory SchedulerCounters.fromJson(Map<String, dynamic> json) {
    return SchedulerCounters(
      cycles: json['cycles'] is num ? (json['cycles'] as num).toInt() : 0,
      wakeAttempts: json['wake_attempts'] is num ? (json['wake_attempts'] as num).toInt() : 0,
      wakeSkipped: json['wake_skipped'] is num ? (json['wake_skipped'] as num).toInt() : 0,
      wakeSucceeded: json['wake_succeeded'] is num ? (json['wake_succeeded'] as num).toInt() : 0,
      wakeFailed: json['wake_failed'] is num ? (json['wake_failed'] as num).toInt() : 0,
      capacityWaitingRuns: json['capacity_waiting_runs'] is num
          ? (json['capacity_waiting_runs'] as num).toInt()
          : 0,
      spawnRequested: json['spawn_requested'] is num ? (json['spawn_requested'] as num).toInt() : 0,
      needsAttention: json['needs_attention'] is num ? (json['needs_attention'] as num).toInt() : 0,
      lastCycleAt: json['last_cycle_at'] != null
          ? DateTime.tryParse(json['last_cycle_at'].toString())
          : null,
    );
  }
}

@immutable
class SchedulerStatus {
  final bool paused;
  final int queuedRunCount;
  final int needsAttentionRunCount;
  final int activeClaimCount;
  final int starvedRunCount;
  final DateTime? asOf;
  final SchedulerCounters counters;

  const SchedulerStatus({
    this.paused = false,
    this.queuedRunCount = 0,
    this.needsAttentionRunCount = 0,
    this.activeClaimCount = 0,
    this.starvedRunCount = 0,
    this.asOf,
    this.counters = const SchedulerCounters(),
  });

  factory SchedulerStatus.fromJson(Map<String, dynamic> json) {
    final rawScheduler = json['scheduler'] is Map
        ? Map<String, dynamic>.from(json['scheduler'] as Map)
        : json;

    return SchedulerStatus(
      paused: rawScheduler['paused'] == true,
      queuedRunCount: rawScheduler['queued_run_count'] is num
          ? (rawScheduler['queued_run_count'] as num).toInt()
          : 0,
      needsAttentionRunCount: rawScheduler['needs_attention_run_count'] is num
          ? (rawScheduler['needs_attention_run_count'] as num).toInt()
          : 0,
      activeClaimCount: rawScheduler['active_claim_count'] is num
          ? (rawScheduler['active_claim_count'] as num).toInt()
          : 0,
      starvedRunCount: rawScheduler['starved_run_count'] is num
          ? (rawScheduler['starved_run_count'] as num).toInt()
          : 0,
      asOf: rawScheduler['as_of'] != null
          ? DateTime.tryParse(rawScheduler['as_of'].toString())
          : null,
      counters: rawScheduler['counters'] is Map
          ? SchedulerCounters.fromJson(Map<String, dynamic>.from(rawScheduler['counters'] as Map))
          : const SchedulerCounters(),
    );
  }
}
