import 'package:flutter/foundation.dart';

@immutable
class AutomationLastRun {
  final String id;
  final String status; // 'scheduled' | 'running' | 'delegated' | 'completed' | 'failed' | 'canceled'
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? skipReason; // 'self_overlap' | 'misfire_grace_exceeded'

  const AutomationLastRun({
    required this.id,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.skipReason,
  });

  factory AutomationLastRun.fromJson(Map<String, dynamic> json) {
    return AutomationLastRun(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'scheduled',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      skipReason: json['skip_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        if (skipReason != null) 'skip_reason': skipReason,
      };
}

@immutable
class AutomationRun {
  final String id;
  final String? jobId;
  final String? triggerId;
  final String? sessionId;
  final String status; // 'scheduled' | 'running' | 'delegated' | 'completed' | 'failed' | 'canceled'
  final int attempt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? error;
  final String? skipReason;
  final Map<String, dynamic> metadata;

  const AutomationRun({
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

  /// Duration if both started and ended are known.
  Duration? get duration {
    if (startedAt != null && endedAt != null) {
      return endedAt!.difference(startedAt!);
    }
    return null;
  }

  /// Formatted duration string, e.g. "45s", "2m 14s", "1h 5m".
  String get durationDisplay {
    final d = duration;
    if (d == null) {
      if (status == 'running') return 'In progress';
      return '—';
    }
    final inSec = d.inSeconds;
    if (inSec < 60) return '${inSec}s';
    final inMin = d.inMinutes;
    final remainingSec = inSec % 60;
    if (inMin < 60) {
      return remainingSec > 0 ? '${inMin}m ${remainingSec}s' : '${inMin}m';
    }
    final inHours = d.inHours;
    final remainingMin = inMin % 60;
    return '${inHours}h ${remainingMin}m';
  }

  /// Whether this run is actively running or scheduled and can be cancelled.
  bool get isCancelable => status == 'running' || status == 'scheduled';

  /// Human-readable capitalized status label.
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'running':
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'canceled':
      case 'cancelled':
        return 'Canceled';
      case 'scheduled':
        return 'Scheduled';
      case 'delegated':
        return 'Delegated';
      default:
        return status;
    }
  }
}
