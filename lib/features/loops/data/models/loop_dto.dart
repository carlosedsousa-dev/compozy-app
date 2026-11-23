import '../../domain/loop_definition.dart';

/// Data Transfer Object for serializing/deserializing CompozyOS Loop definitions.
class LoopDto {
  final String name;
  final String description;
  final String? category;
  final Map<String, dynamic> contract;
  final Map<String, dynamic> inputs;

  const LoopDto({
    required this.name,
    required this.description,
    this.category,
    this.contract = const {},
    this.inputs = const {},
  });

  factory LoopDto.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Unnamed Loop';
    final description = json['description']?.toString() ?? '';

    // Category can be at top level or nested in 'catalog' map.
    final category = json['category']?.toString() ??
        (json['catalog'] is Map
            ? (json['catalog'] as Map)['category']?.toString()
            : null);

    Map<String, dynamic> contract = const {};
    if (json['contract'] is Map) {
      contract = Map<String, dynamic>.from(json['contract'] as Map);
    }

    Map<String, dynamic> inputs = const {};
    if (json['inputs'] is Map) {
      inputs = Map<String, dynamic>.from(json['inputs'] as Map);
    }

    return LoopDto(
      name: name,
      description: description,
      category: category,
      contract: contract,
      inputs: inputs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (category != null) 'category': category,
      'contract': contract,
      'inputs': inputs,
    };
  }

  LoopDefinition toDomain() {
    return LoopDefinition(
      name: name,
      description: description,
      category: category,
      contract: contract,
      inputs: inputs,
    );
  }
}
