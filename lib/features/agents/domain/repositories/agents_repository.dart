import '../models/agent_activity.dart';
import '../models/agent_presence.dart';

export '../models/agent_activity.dart';
export '../models/agent_definition.dart';
export '../models/agent_presence.dart';

/// Domain interface for retrieving CompozyOS agent definitions and presence.
abstract class AgentsRepository {
  /// Fetches all registered agents from the CompozyOS daemon.
  Future<List<AgentDefinition>> getAgents();

  /// Fetches joined agent definitions with presence derived from active sessions.
  Future<List<AgentPresence>> getAgentsPresence();

  /// Fetches telemetry and activity metrics for a specific agent by [name].
  Future<AgentActivity> getAgentActivity(String name);
}
