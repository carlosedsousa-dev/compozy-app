import 'package:flutter/foundation.dart';

/// Effective runtime configuration resolved by the CompozyOS daemon for an agent.
@immutable
class AgentEffectiveRuntime {
  final String provider;
  final String model;
  final String reasoningEffort;
  final String? permissions;
  final String? speed;
  final Map<String, dynamic> sources;

  const AgentEffectiveRuntime({
    required this.provider,
    required this.model,
    required this.reasoningEffort,
    this.permissions,
    this.speed,
    this.sources = const {},
  });

  factory AgentEffectiveRuntime.fromJson(Map<String, dynamic> json) {
    return AgentEffectiveRuntime(
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      reasoningEffort: json['reasoning_effort']?.toString() ?? 'default',
      permissions: json['permissions']?.toString(),
      speed: json['speed']?.toString(),
      sources: json['sources'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['sources'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'model': model,
      'reasoning_effort': reasoningEffort,
      if (permissions != null) 'permissions': permissions,
      if (speed != null) 'speed': speed,
      'sources': sources,
    };
  }
}
