import 'package:flutter/foundation.dart';

/// Domain entity representing a CompozyOS Loop definition.
@immutable
class LoopDefinition {
  final String name;
  final String description;
  final String? category;
  final Map<String, dynamic> contract;
  final Map<String, dynamic> inputs;

  const LoopDefinition({
    required this.name,
    required this.description,
    this.category,
    this.contract = const {},
    this.inputs = const {},
  });

  /// Convenient display category defaulting to 'General' when null.
  String get categoryDisplay => category ?? 'General';

  /// Contract goal if defined.
  String get goal => (contract['goal']?.toString()) ?? '';

  /// Contract definition of done if defined.
  String get definitionOfDone =>
      (contract['definition_of_done']?.toString()) ??
      (contract['definitionOfDone']?.toString()) ??
      '';

  LoopDefinition copyWith({
    String? name,
    String? description,
    String? category,
    Map<String, dynamic>? contract,
    Map<String, dynamic>? inputs,
  }) {
    return LoopDefinition(
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      contract: contract ?? this.contract,
      inputs: inputs ?? this.inputs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopDefinition &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          category == other.category &&
          mapEquals(contract, other.contract) &&
          mapEquals(inputs, other.inputs);

  @override
  int get hashCode =>
      name.hashCode ^
      description.hashCode ^
      category.hashCode ^
      contract.length.hashCode ^
      inputs.length.hashCode;

  @override
  String toString() {
    return 'LoopDefinition(name: $name, category: $category, description: $description, contract: $contract, inputs: $inputs)';
  }
}
