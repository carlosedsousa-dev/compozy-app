import 'package:flutter/foundation.dart';

/// Domain entity representing a CompozyOS session.
@immutable
class Session {
  final String id;
  final String name;
  final String agent;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    required this.name,
    required this.agent,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  Session copyWith({
    String? id,
    String? name,
    String? agent,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      agent: agent ?? this.agent,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          agent == other.agent &&
          state == other.state &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      agent.hashCode ^
      state.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Session(id: $id, name: $name, agent: $agent, state: $state, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
