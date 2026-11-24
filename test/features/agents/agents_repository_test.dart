import 'package:flutter_test/flutter_test.dart';

import 'package:compozy_app/features/agents/data/agents_repository_impl.dart';
import 'package:compozy_app/features/agents/data/models/agent_dto.dart';
import 'package:compozy_app/features/agents/data/models/agent_session_dto.dart';
import 'package:compozy_app/features/agents/data/sources/agents_remote_data_source.dart';
import 'package:compozy_app/features/agents/domain/repositories/agents_repository.dart';

class FakeAgentsRemoteDataSource implements AgentsRemoteDataSource {
  final List<AgentDto> agents;
  final List<AgentSessionDto> sessions;
  final AgentActivity activity;

  FakeAgentsRemoteDataSource({
    this.agents = const [],
    this.sessions = const [],
    this.activity = const AgentActivity(),
  });

  @override
  Future<List<AgentDto>> getAgents() async => agents;

  @override
  Future<List<AgentSessionDto>> getAgentSessions() async => sessions;

  @override
  Future<AgentActivity> getAgentActivity(String name) async => activity;
}

void main() {
  group('AgentsRepository & Live Presence Derivation', () {
    const designerAgent = AgentDefinition(
      name: 'designer',
      label: 'Designer',
      kind: 'on_demand',
      provider: 'agy',
      model: 'gemini-3.8-flash',
      appearance: AgentAppearance(
        avatar: 'generated',
        colorHex: '#7c5cff',
        seed: 'designer',
      ),
      toolsets: ['compozy__catalog'],
      categoryPath: ['CompozyOS'],
      origin: 'global',
    );

    const fixerAgent = AgentDefinition(
      name: 'fixer',
      label: 'Fixer',
      kind: 'on_demand',
      appearance: AgentAppearance(
        avatar: 'generated',
        colorHex: '#d97706',
        seed: 'fixer',
      ),
      toolsets: ['compozy__terminal'],
      categoryPath: ['Engineering'],
      origin: 'global',
    );

    const idleAgent = AgentDefinition(
      name: 'oracle',
      label: 'Oracle',
      kind: 'on_demand',
      appearance: AgentAppearance(
        avatar: 'generated',
        colorHex: '#8b5cf6',
        seed: 'oracle',
      ),
      toolsets: ['compozy__catalog'],
      categoryPath: ['CompozyOS'],
      origin: 'global',
    );

    test('derives "working" signal when session has board_column "working"', () {
      final sessions = [
        const AgentSessionDto(
          id: 'sess-1',
          name: 'Wave b4',
          agent: 'designer',
          state: 'active',
          boardColumn: 'working',
        ),
      ];

      final presence = AgentsRepositoryImpl.joinAgentsWithSessions(
        [designerAgent],
        sessions,
      );

      expect(presence.length, 1);
      expect(presence.first.status, AgentPresenceStatus.working);
      expect(presence.first.workingSessionsCount, 1);
      expect(presence.first.waitingSessionsCount, 0);
      expect(presence.first.totalSessionsCount, 1);
      expect(presence.first.isWorking, isTrue);
    });

    test('derives "needs-you" signal when session children require attention', () {
      final sessions = [
        const AgentSessionDto(
          id: 'sess-2',
          name: 'Bug fixing lane',
          agent: 'fixer',
          state: 'active',
          boardColumn: 'working',
          childrenNeedsYou: 2,
          childrenTotal: 5,
        ),
      ];

      final presence = AgentsRepositoryImpl.joinAgentsWithSessions(
        [fixerAgent],
        sessions,
      );

      expect(presence.length, 1);
      expect(presence.first.status, AgentPresenceStatus.needsYou);
      expect(presence.first.waitingSessionsCount, 1);
      expect(presence.first.workingSessionsCount, 0);
      expect(presence.first.isNeedsYou, isTrue);
    });

    test('derives "needs-you" signal when board_column is "waiting"', () {
      final sessions = [
        const AgentSessionDto(
          id: 'sess-3',
          name: 'Approval needed',
          agent: 'fixer',
          state: 'active',
          boardColumn: 'waiting',
        ),
      ];

      final presence = AgentsRepositoryImpl.joinAgentsWithSessions(
        [fixerAgent],
        sessions,
      );

      expect(presence.length, 1);
      expect(presence.first.status, AgentPresenceStatus.needsYou);
      expect(presence.first.waitingSessionsCount, 1);
    });

    test('derives "idle" signal when agent has no active sessions', () {
      final sessions = [
        const AgentSessionDto(
          id: 'sess-4',
          name: 'Finished research',
          agent: 'oracle',
          state: 'stopped',
          boardColumn: 'done',
        ),
      ];

      final presence = AgentsRepositoryImpl.joinAgentsWithSessions(
        [idleAgent],
        sessions,
      );

      expect(presence.length, 1);
      expect(presence.first.status, AgentPresenceStatus.idle);
      expect(presence.first.workingSessionsCount, 0);
      expect(presence.first.waitingSessionsCount, 0);
      expect(presence.first.totalSessionsCount, 1);
      expect(presence.first.isIdle, isTrue);
    });

    test('AgentActivity parsing handles telemetry honestly', () {
      final rawActivity = {
        'reports_by_day': [],
        'cost_by_project': [
          {
            'workspace_id': 'ws_1',
            'scope': 'compozy-app',
            'usd_estimate': 0.0877,
            'tokens': 24500000,
          },
        ],
        'busy_by_hour': [
          {
            'weekday': 0,
            'hour': 21,
            'events': 571,
          },
        ],
      };

      final activity = AgentActivity.fromJson(rawActivity);
      expect(activity.isEmpty, isFalse);
      expect(activity.totalTokens, 24500000);
      expect(activity.totalUsdEstimate, closeTo(0.0877, 0.0001));
      expect(activity.totalEvents, 571);
      expect(activity.costByProject.first.scope, 'compozy-app');
    });

    test('AgentActivity reports empty when no data recorded', () {
      final emptyActivity = AgentActivity.fromJson({
        'reports_by_day': [],
        'cost_by_project': [],
        'busy_by_hour': [],
      });

      expect(emptyActivity.isEmpty, isTrue);
      expect(emptyActivity.totalTokens, 0);
      expect(emptyActivity.totalUsdEstimate, 0.0);
    });
  });
}
