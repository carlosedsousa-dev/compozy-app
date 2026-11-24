import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/agents_repository.dart';
import 'agents_repository_impl.dart';
import 'sources/agents_remote_data_source.dart';

export '../domain/models/agent_activity.dart';
export '../domain/models/agent_appearance.dart';
export '../domain/models/agent_definition.dart';
export '../domain/models/agent_effective_runtime.dart';
export '../domain/models/agent_presence.dart';
export '../domain/repositories/agents_repository.dart';
export 'models/agent_dto.dart';
export 'models/agent_session_dto.dart';
export 'sources/agents_remote_data_source.dart';

/// Riverpod provider for [AgentsRepository].
final agentsRepositoryProvider = Provider<AgentsRepository>((ref) {
  final remoteDataSource = ref.watch(agentsRemoteDataSourceProvider);
  return AgentsRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Riverpod provider fetching raw agent definitions from /api/agents.
final agentsProvider = FutureProvider<List<AgentDefinition>>((ref) async {
  final repository = ref.watch(agentsRepositoryProvider);
  return repository.getAgents();
});

/// Alias for [agentsProvider].
final agentsListProvider = agentsProvider;

/// Riverpod provider fetching live agent presence joined with active sessions.
final agentsPresenceProvider = FutureProvider<List<AgentPresence>>((ref) async {
  final repository = ref.watch(agentsRepositoryProvider);
  return repository.getAgentsPresence();
});

/// Riverpod provider for active filter chip: 'All', 'Working', 'Needs you', 'Idle'.
final agentFilterProvider = StateProvider<String>((ref) => 'All');

/// Riverpod provider for search text field query.
final agentSearchProvider = StateProvider<String>((ref) => '');

/// Riverpod provider delivering filtered and prioritized agent presence list.
/// Prioritization order: "Needs you" first, then "Working", then "Idle", sorted by label.
final filteredAgentsProvider = Provider<AsyncValue<List<AgentPresence>>>((ref) {
  final presenceAsync = ref.watch(agentsPresenceProvider);
  final filter = ref.watch(agentFilterProvider);
  final query = ref.watch(agentSearchProvider).trim().toLowerCase();

  return presenceAsync.whenData((list) {
    // 1. Filter by chip
    final chipFiltered = list.where((p) {
      final f = filter.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();
      if (f == 'all') return true;
      if (f == 'needs you') return p.isNeedsYou;
      if (f == 'working' || f == 'active') return p.isWorking;
      if (f == 'idle') return p.isIdle;
      return true;
    }).toList();

    // 2. Filter by search query (label, name, or category)
    final searchFiltered = query.isEmpty
        ? chipFiltered
        : chipFiltered.where((p) {
            final nameMatch = p.agent.name.toLowerCase().contains(query);
            final labelMatch = p.agent.label.toLowerCase().contains(query);
            final catMatch = p.agent.categoryDisplay.toLowerCase().contains(query);
            return nameMatch || labelMatch || catMatch;
          }).toList();

    // 3. Sort: "Needs you" attention items first, then "Working", then "Idle", then alphabetically
    final sorted = List<AgentPresence>.from(searchFiltered);
    sorted.sort((a, b) {
      if (a.isNeedsYou && !b.isNeedsYou) return -1;
      if (!a.isNeedsYou && b.isNeedsYou) return 1;
      if (a.isWorking && !b.isWorking) return -1;
      if (!a.isWorking && b.isWorking) return 1;
      return a.agent.label.toLowerCase().compareTo(b.agent.label.toLowerCase());
    });

    return sorted;
  });
});

/// Family provider fetching telemetry and activity metrics for a specific agent.
final agentActivityProvider =
    FutureProvider.family<AgentActivity, String>((ref, agentName) async {
  final repository = ref.watch(agentsRepositoryProvider);
  return repository.getAgentActivity(agentName);
});
