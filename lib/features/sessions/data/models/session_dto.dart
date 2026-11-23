import '../../domain/models/session.dart';

/// Data Transfer Object for serializing/deserializing CompozyOS sessions.
class SessionDto {
  final String id;
  final String name;
  final String agent;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionDto({
    required this.id,
    required this.name,
    required this.agent,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? 'Untitled Session';
    final agent = json['agent']?.toString() ??
        json['agent_name']?.toString() ??
        'general';
    final state = json['state']?.toString() ?? 'idle';

    final createdAt = parseDate(json['createdAt'] ?? json['created_at']);
    final updatedAt = parseDate(
      json['updatedAt'] ??
          json['updated_at'] ??
          json['createdAt'] ??
          json['created_at'],
    );

    return SessionDto(
      id: id,
      name: name,
      agent: agent,
      state: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'agent': agent,
      'state': state,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Session toDomain() {
    return Session(
      id: id,
      name: name,
      agent: agent,
      state: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
