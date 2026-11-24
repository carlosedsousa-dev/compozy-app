import '../domain/repositories/agents_repository.dart';
import 'models/agent_session_dto.dart';
import 'sources/agents_remote_data_source.dart';

/// Implementation of [AgentsRepository] coordinating agent catalogs and session presence.
class AgentsRepositoryImpl implements AgentsRepository {
  final AgentsRemoteDataSource remoteDataSource;

  AgentsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AgentDefinition>> getAgents() async {
    final dtos = await remoteDataSource.getAgents();
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<List<AgentPresence>> getAgentsPresence() async {
    final agentsFuture = getAgents();
    final sessionsFuture = remoteDataSource.getAgentSessions();

    final agents = await agentsFuture;
    final sessions = await sessionsFuture;

    return joinAgentsWithSessions(agents, sessions);
  }

  @override
  Future<AgentActivity> getAgentActivity(String name) async {
    return remoteDataSource.getAgentActivity(name);
  }

  /// Deterministically joins agent definitions with active sessions by agent name.
  static List<AgentPresence> joinAgentsWithSessions(
    List<AgentDefinition> agents,
    List<AgentSessionDto> sessions,
  ) {
    final sessionsByAgent = <String, List<AgentSessionDto>>{};
    for (final s in sessions) {
      final key = s.agent.toLowerCase().trim();
      sessionsByAgent.putIfAbsent(key, () => []).add(s);
    }

    return agents.map((agent) {
      final agentKey = agent.name.toLowerCase().trim();
      final agentSessions = sessionsByAgent[agentKey] ?? const [];

      int workingSessionsCount = 0;
      int waitingSessionsCount = 0;
      final totalSessionsCount = agentSessions.length;

      for (final s in agentSessions) {
        if (s.isNeedsYou) {
          waitingSessionsCount++;
        } else if (s.isWorking) {
          workingSessionsCount++;
        }
      }

      final AgentPresenceStatus status;
      if (waitingSessionsCount > 0) {
        status = AgentPresenceStatus.needsYou;
      } else if (workingSessionsCount > 0) {
        status = AgentPresenceStatus.working;
      } else {
        status = AgentPresenceStatus.idle;
      }

      return AgentPresence(
        agent: agent,
        status: status,
        workingSessionsCount: workingSessionsCount,
        waitingSessionsCount: waitingSessionsCount,
        totalSessionsCount: totalSessionsCount,
      );
    }).toList();
  }
}
