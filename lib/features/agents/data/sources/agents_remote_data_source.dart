import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/compozy_api_client.dart';
import '../../domain/models/agent_activity.dart';
import '../models/agent_dto.dart';
import '../models/agent_session_dto.dart';

/// Riverpod provider for [AgentsRemoteDataSource].
final agentsRemoteDataSourceProvider = Provider<AgentsRemoteDataSource>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  return AgentsRemoteDataSourceImpl(apiClient: apiClient);
});

/// Contract for communicating with CompozyOS daemon agents endpoints.
abstract class AgentsRemoteDataSource {
  Future<List<AgentDto>> getAgents();
  Future<List<AgentSessionDto>> getAgentSessions();
  Future<AgentActivity> getAgentActivity(String name);
}

/// Implementation of [AgentsRemoteDataSource] using [CompozyApiClient].
class AgentsRemoteDataSourceImpl implements AgentsRemoteDataSource {
  final CompozyApiClient apiClient;

  AgentsRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<AgentDto>> getAgents() async {
    final response = await apiClient.get('/api/agents');
    final rawList = response['agents'] ??
        response['entries'] ??
        response['data'] ??
        response['items'];

    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => AgentDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<List<AgentSessionDto>> getAgentSessions() async {
    final response = await apiClient.get(
      '/api/sessions',
      queryParameters: {'all_workspaces': 'true'},
    );
    final rawList = response['sessions'] ??
        response['entries'] ??
        response['data'] ??
        response['items'];

    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => AgentSessionDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<AgentActivity> getAgentActivity(String name) async {
    try {
      final response = await apiClient.get('/api/agents/$name/activity');
      return AgentActivity.fromJson(response);
    } catch (_) {
      return const AgentActivity();
    }
  }
}
