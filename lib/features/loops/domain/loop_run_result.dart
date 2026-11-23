import 'package:flutter/foundation.dart';

/// Domain entity representing the result of triggering a CompozyOS Loop run.
@immutable
class LoopRunResult {
  final String runId;
  final String status;
  final String? loopName;
  final Map<String, dynamic> raw;

  const LoopRunResult({
    required this.runId,
    required this.status,
    this.loopName,
    this.raw = const {},
  });

  factory LoopRunResult.fromJson(Map<String, dynamic> json) {
    String runId = '';
    String status = 'queued';
    String? loopName;

    if (json.containsKey('run') && json['run'] is Map) {
      final runMap = Map<String, dynamic>.from(json['run'] as Map);
      runId = runMap['id']?.toString() ??
          runMap['run_id']?.toString() ??
          runMap['runId']?.toString() ??
          '';
      status = runMap['status']?.toString() ?? status;
      loopName = runMap['loop_name']?.toString() ?? runMap['name']?.toString();
    } else {
      runId = json['run_id']?.toString() ??
          json['id']?.toString() ??
          json['runId']?.toString() ??
          '';
      status = json['status']?.toString() ?? status;
      loopName = json['loop_name']?.toString() ?? json['name']?.toString();
    }

    return LoopRunResult(
      runId: runId,
      status: status,
      loopName: loopName,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'run_id': runId,
        'status': status,
        if (loopName != null) 'loop_name': loopName,
        'raw': raw,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopRunResult &&
          runtimeType == other.runtimeType &&
          runId == other.runId &&
          status == other.status &&
          loopName == other.loopName;

  @override
  int get hashCode => runId.hashCode ^ status.hashCode ^ loopName.hashCode;

  @override
  String toString() =>
      'LoopRunResult(runId: $runId, status: $status, loopName: $loopName)';
}
