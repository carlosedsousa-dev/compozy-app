import 'package:flutter/foundation.dart';

import 'agent_appearance.dart';
import 'agent_effective_runtime.dart';

export 'agent_appearance.dart';
export 'agent_effective_runtime.dart';

/// Domain entity representing a CompozyOS agent definition.
@immutable
class AgentDefinition {
  final String name;
  final String label;
  final String kind;
  final String? provider;
  final String? model;
  final List<String> toolsets;
  final List<String> categoryPath;
  final String origin;
  final bool packageOwned;
  final AgentAppearance appearance;
  final String prompt;
  final String? definitionDigest;
  final AgentEffectiveRuntime? effectiveRuntime;
  final Map<String, dynamic> skills;

  const AgentDefinition({
    required this.name,
    required this.label,
    required this.kind,
    this.provider,
    this.model,
    this.toolsets = const [],
    this.categoryPath = const [],
    this.origin = 'global',
    this.packageOwned = true,
    required this.appearance,
    this.prompt = '',
    this.definitionDigest,
    this.effectiveRuntime,
    this.skills = const {},
  });

  /// Display representation of category, e.g. "CompozyOS".
  String get categoryDisplay =>
      categoryPath.isNotEmpty ? categoryPath.join(' / ') : 'General';

  /// Human-readable kind representation ("On-demand" vs "Always-on").
  String get kindDisplay {
    final k = kind.toLowerCase().replaceAll('_', '-');
    if (k == 'always-on') return 'Always-on';
    return 'On-demand';
  }

  /// Whether the agent explicitly pins a provider or model.
  bool get isPinned =>
      (provider != null && provider!.isNotEmpty) ||
      (model != null && model!.isNotEmpty);

  /// Pinned monospace pill text when present.
  String? get pinnedRuntimeDisplay {
    if (!isPinned) return null;
    final p = provider ?? '';
    final m = model ?? '';
    if (p.isNotEmpty && m.isNotEmpty) {
      return '$p · $m';
    }
    return p.isNotEmpty ? p : m;
  }
}
