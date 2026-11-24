import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:compozy_app/core/network/api_exceptions.dart';
import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/features/automations/data/automation_repository_impl.dart';

class FakeApiClient implements CompozyApiClient {
  final Map<String, dynamic> Function(String path, Map<String, dynamic>? queryParameters)? onGet;
  final Map<String, dynamic> Function(String path, dynamic data)? onPost;

  FakeApiClient({this.onGet, this.onPost});

  @override
  String get baseUrl => 'http://localhost:2123';

  @override
  String? get appToken => null;

  @override
  Dio get dio => throw UnimplementedError();

  @override
  void updateBaseUrl(String newBaseUrl) {}

  @override
  void updateAppToken(String? newAppToken) {}

  @override
  void updateConfiguration({String? baseUrl, String? appToken}) {}

  @override
  void updateSettings(dynamic settings) {}

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (onGet != null) {
      return onGet!(path, queryParameters);
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (onPost != null) {
      return onPost!(path, data);
    }
    return {};
  }
}

void main() {
  group('AutomationRepository & RemoteDataSource', () {
    test('getJobs returns mapped AutomationJob list', () async {
      final fakeApi = FakeApiClient(
        onGet: (path, params) {
          expect(path, '/api/automation/jobs');
          expect(params?['all_workspaces'], 'true');
          return {
            'jobs': [
              {
                'id': 'job_123',
                'name': 'Daily standup',
                'agent_name': 'dispatcher',
                'prompt': 'Write standup summary',
                'enabled': true,
                'target_kind': 'agent',
                'schedule': {'mode': 'cron', 'expr': '0 9 * * 1-5'},
                'retry': {'strategy': 'backoff', 'max_retries': 3, 'base_delay': '5s'},
                'fire_limit': {'max': 12, 'window': '1h'},
                'last_run': {
                  'id': 'run_001',
                  'status': 'completed',
                  'started_at': '2026-11-24T10:00:00Z',
                  'ended_at': '2026-11-24T10:00:45Z',
                },
              }
            ],
            'page': {'has_more': false, 'total': 1, 'limit': 50},
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final jobs = await repository.getJobs();
      expect(jobs.length, 1);
      final job = jobs.first;
      expect(job.id, 'job_123');
      expect(job.name, 'Daily standup');
      expect(job.agentName, 'dispatcher');
      expect(job.targetDisplay, 'Agent: dispatcher');
      expect(job.schedule?.expr, '0 9 * * 1-5');
      expect(job.retry.maxRetries, 3);
      expect(job.retry.displayDescription, 'Backoff, up to 3 retries (5s base)');
      expect(job.fireLimit.displayDescription, 'Max 12 runs / 1h');
      expect(job.lastRun?.status, 'completed');
    });

    test('getJobRuns parses run list with durations', () async {
      final fakeApi = FakeApiClient(
        onGet: (path, _) {
          expect(path, '/api/automation/jobs/job_123/runs');
          return {
            'runs': [
              {
                'id': 'run_001',
                'job_id': 'job_123',
                'status': 'running',
                'attempt': 1,
                'started_at': '2026-11-24T10:00:00Z',
              },
              {
                'id': 'run_002',
                'job_id': 'job_123',
                'status': 'completed',
                'attempt': 1,
                'started_at': '2026-11-24T09:00:00Z',
                'ended_at': '2026-11-24T09:01:30Z',
              },
            ]
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final runs = await repository.getJobRuns('job_123');
      expect(runs.length, 2);
      expect(runs[0].status, 'running');
      expect(runs[0].isCancelable, isTrue);
      expect(runs[0].durationDisplay, 'In progress');
      expect(runs[1].status, 'completed');
      expect(runs[1].isCancelable, isFalse);
      expect(runs[1].durationDisplay, '1m 30s');
    });

    test('triggerJob calls POST /api/automation/jobs/:id/trigger', () async {
      final fakeApi = FakeApiClient(
        onPost: (path, _) {
          expect(path, '/api/automation/jobs/job_123/trigger');
          return {
            'run': {
              'id': 'run_new',
              'job_id': 'job_123',
              'status': 'scheduled',
              'attempt': 1,
            }
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final run = await repository.triggerJob('job_123');
      expect(run.id, 'run_new');
      expect(run.status, 'scheduled');
    });

    test('cancelRun calls POST /api/automation/runs/:id/cancel', () async {
      final fakeApi = FakeApiClient(
        onPost: (path, _) {
          expect(path, '/api/automation/runs/run_001/cancel');
          return {
            'run': {
              'id': 'run_001',
              'status': 'canceled',
            }
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final run = await repository.cancelRun('run_001');
      expect(run.id, 'run_001');
      expect(run.status, 'canceled');
    });

    test('getTriggers parses webhook and event triggers', () async {
      final fakeApi = FakeApiClient(
        onGet: (path, params) {
          expect(path, '/api/automation/triggers');
          return {
            'triggers': [
              {
                'id': 'trig_01',
                'name': 'Deploy Webhook',
                'agent_name': 'dispatcher',
                'event': 'webhook',
                'endpoint_slug': 'deploy-prod',
                'enabled': true,
              }
            ]
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final triggers = await repository.getTriggers();
      expect(triggers.length, 1);
      expect(triggers.first.endpointSlug, 'deploy-prod');
      expect(triggers.first.targetDisplay, 'Agent: dispatcher');
    });

    test('getSchedulerStatus parses scheduler state and counters', () async {
      final fakeApi = FakeApiClient(
        onGet: (path, _) {
          expect(path, '/api/scheduler');
          return {
            'scheduler': {
              'paused': true,
              'queued_run_count': 2,
              'needs_attention_run_count': 1,
              'counters': {
                'cycles': 500,
                'wake_succeeded': 490,
                'needs_attention': 1,
              }
            }
          };
        },
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      final status = await repository.getSchedulerStatus();
      expect(status.paused, isTrue);
      expect(status.queuedRunCount, 2);
      expect(status.needsAttentionRunCount, 1);
      expect(status.counters.cycles, 500);
    });

    test('propagates CompozyApiException on failure', () async {
      final fakeApi = FakeApiClient(
        onGet: (path, _) => throw CompozyApiException(
          message: 'Connection refused',
          statusCode: 503,
        ),
      );

      final dataSource = AutomationRemoteDataSourceImpl(apiClient: fakeApi);
      final repository = AutomationRepositoryImpl(remoteDataSource: dataSource);

      expect(
        () => repository.getJobs(),
        throwsA(isA<CompozyApiException>()),
      );
    });
  });
}
