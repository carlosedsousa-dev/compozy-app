import 'package:flutter/foundation.dart';

/// Project cost and token usage breakdown for an agent.
@immutable
class AgentProjectCost {
  final String workspaceId;
  final String scope;
  final double usdEstimate;
  final int tokens;

  const AgentProjectCost({
    required this.workspaceId,
    required this.scope,
    required this.usdEstimate,
    required this.tokens,
  });

  factory AgentProjectCost.fromJson(Map<String, dynamic> json) {
    return AgentProjectCost(
      workspaceId: json['workspace_id']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      usdEstimate: (json['usd_estimate'] is num)
          ? (json['usd_estimate'] as num).toDouble()
          : 0.0,
      tokens: (json['tokens'] is num) ? (json['tokens'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workspace_id': workspaceId,
      'scope': scope,
      'usd_estimate': usdEstimate,
      'tokens': tokens,
    };
  }
}

/// Hour-of-week busy slot for an agent.
@immutable
class AgentBusyHour {
  final int weekday;
  final int hour;
  final int events;

  const AgentBusyHour({
    required this.weekday,
    required this.hour,
    required this.events,
  });

  factory AgentBusyHour.fromJson(Map<String, dynamic> json) {
    return AgentBusyHour(
      weekday: (json['weekday'] is num) ? (json['weekday'] as num).toInt() : 0,
      hour: (json['hour'] is num) ? (json['hour'] as num).toInt() : 0,
      events: (json['events'] is num) ? (json['events'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'hour': hour,
      'events': events,
    };
  }
}

/// Detailed telemetry and activity metrics for an agent.
@immutable
class AgentActivity {
  final List<dynamic> reportsByDay;
  final List<AgentProjectCost> costByProject;
  final List<AgentBusyHour> busyByHour;

  const AgentActivity({
    this.reportsByDay = const [],
    this.costByProject = const [],
    this.busyByHour = const [],
  });

  factory AgentActivity.fromJson(Map<String, dynamic> json) {
    final rawReports = json['reports_by_day'];
    final rawCost = json['cost_by_project'];
    final rawBusy = json['busy_by_hour'];

    return AgentActivity(
      reportsByDay: rawReports is List ? rawReports : const [],
      costByProject: rawCost is List
          ? rawCost
              .whereType<Map>()
              .map((m) => AgentProjectCost.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      busyByHour: rawBusy is List
          ? rawBusy
              .whereType<Map>()
              .map((m) => AgentBusyHour.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
    );
  }

  bool get isEmpty =>
      reportsByDay.isEmpty && costByProject.isEmpty && busyByHour.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalTokens =>
      costByProject.fold(0, (sum, item) => sum + item.tokens);

  double get totalUsdEstimate =>
      costByProject.fold(0.0, (sum, item) => sum + item.usdEstimate);

  int get totalEvents =>
      busyByHour.fold(0, (sum, item) => sum + item.events);
}
