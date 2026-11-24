import 'package:flutter/foundation.dart';

/// Resolved visual appearance parameters for an agent from CompozyOS daemon.
@immutable
class AgentAppearance {
  final String avatar;
  final String? colorHex;
  final String? seed;
  final int? generation;
  final int? version;
  final String? icon;

  const AgentAppearance({
    required this.avatar,
    this.colorHex,
    this.seed,
    this.generation,
    this.version,
    this.icon,
  });

  factory AgentAppearance.fromJson(Map<String, dynamic> json) {
    return AgentAppearance(
      avatar: json['avatar']?.toString() ?? 'generated',
      colorHex: json['color']?.toString(),
      seed: json['seed']?.toString(),
      generation: json['generation'] is int ? json['generation'] as int : null,
      version: json['version'] is int ? json['version'] as int : null,
      icon: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avatar': avatar,
      if (colorHex != null) 'color': colorHex,
      if (seed != null) 'seed': seed,
      if (generation != null) 'generation': generation,
      if (version != null) 'version': version,
      if (icon != null) 'icon': icon,
    };
  }
}
