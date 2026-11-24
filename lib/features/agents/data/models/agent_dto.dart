import '../../domain/models/agent_definition.dart';

/// Data transfer object for deserializing CompozyOS agent specifications from /api/agents.
class AgentDto {
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

  const AgentDto({
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

  factory AgentDto.fromJson(Map<String, dynamic> json) {
    final rawAppearance = json['resolved_appearance'];
    final appearance = rawAppearance is Map
        ? AgentAppearance.fromJson(Map<String, dynamic>.from(rawAppearance))
        : const AgentAppearance(avatar: 'generated');

    final rawRuntime = json['effective_runtime'];
    final effectiveRuntime = rawRuntime is Map
        ? AgentEffectiveRuntime.fromJson(Map<String, dynamic>.from(rawRuntime))
        : null;

    final rawToolsets = json['toolsets'];
    final toolsets = rawToolsets is List
        ? rawToolsets.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final rawCat = json['category_path'];
    final categoryPath = rawCat is List
        ? rawCat.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
        : const <String>[];

    final rawSkills = json['skills'];
    final skills = rawSkills is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawSkills)
        : (rawSkills is Map ? Map<String, dynamic>.from(rawSkills) : const <String, dynamic>{});

    return AgentDto(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? 'Agent',
      kind: json['kind']?.toString() ?? 'on_demand',
      provider: json['provider']?.toString(),
      model: json['model']?.toString(),
      toolsets: toolsets,
      categoryPath: categoryPath,
      origin: json['origin']?.toString() ?? 'global',
      packageOwned: json['package_owned'] is bool ? json['package_owned'] as bool : true,
      appearance: appearance,
      prompt: json['prompt']?.toString() ?? '',
      definitionDigest: json['definition_digest']?.toString(),
      effectiveRuntime: effectiveRuntime,
      skills: skills,
    );
  }

  AgentDefinition toDomain() {
    return AgentDefinition(
      name: name,
      label: label,
      kind: kind,
      provider: provider,
      model: model,
      toolsets: toolsets,
      categoryPath: categoryPath,
      origin: origin,
      packageOwned: packageOwned,
      appearance: appearance,
      prompt: prompt,
      definitionDigest: definitionDigest,
      effectiveRuntime: effectiveRuntime,
      skills: skills,
    );
  }
}
