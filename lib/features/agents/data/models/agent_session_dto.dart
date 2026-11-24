/// Session presence data transfer object parsed from /api/sessions
/// with board column and child attention metrics.
class AgentSessionDto {
  final String id;
  final String name;
  final String agent;
  final String state;
  final String? boardColumn;
  final int childrenNeedsYou;
  final int childrenWorking;
  final int childrenTotal;

  const AgentSessionDto({
    required this.id,
    required this.name,
    required this.agent,
    required this.state,
    this.boardColumn,
    this.childrenNeedsYou = 0,
    this.childrenWorking = 0,
    this.childrenTotal = 0,
  });

  factory AgentSessionDto.fromJson(Map<String, dynamic> json) {
    final agent = json['agent']?.toString() ??
        json['agent_name']?.toString() ??
        'general';
    final state = json['state']?.toString() ?? 'idle';
    final boardColumn = json['board_column']?.toString();

    int childrenNeedsYou = 0;
    int childrenWorking = 0;
    int childrenTotal = 0;
    final rawChildren = json['children'];
    if (rawChildren is Map) {
      childrenNeedsYou = (rawChildren['needs_you'] is num)
          ? (rawChildren['needs_you'] as num).toInt()
          : 0;
      childrenWorking = (rawChildren['working'] is num)
          ? (rawChildren['working'] as num).toInt()
          : 0;
      childrenTotal = (rawChildren['total'] is num)
          ? (rawChildren['total'] as num).toInt()
          : 0;
    }

    return AgentSessionDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      agent: agent,
      state: state,
      boardColumn: boardColumn,
      childrenNeedsYou: childrenNeedsYou,
      childrenWorking: childrenWorking,
      childrenTotal: childrenTotal,
    );
  }

  /// Whether this session requires triage / user attention.
  bool get isNeedsYou {
    if (childrenNeedsYou > 0) return true;
    if (boardColumn != null) {
      final col = boardColumn!.toLowerCase();
      if (col == 'waiting' || col == 'needs-you' || col == 'needs_you') {
        return true;
      }
    }
    final s = state.toLowerCase().replaceAll('_', '-').trim();
    return s == 'waiting' ||
        s == 'needs-input' ||
        s == 'needs-you' ||
        s == 'needs you' ||
        s == 'blocked';
  }

  /// Whether this session is actively working.
  bool get isWorking {
    if (isNeedsYou) return false;
    if (boardColumn != null) {
      final col = boardColumn!.toLowerCase();
      if (col == 'working') return true;
      if (col == 'done' || col == 'stopped' || col == 'in_review') return false;
    }
    final s = state.toLowerCase();
    return s == 'active' || s == 'working' || s == 'busy';
  }
}
