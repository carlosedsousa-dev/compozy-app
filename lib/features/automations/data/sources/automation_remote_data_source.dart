import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/compozy_api_client.dart';
import '../../domain/models/scheduler_status.dart';
import '../models/automation_dto.dart';

/// Riverpod provider for [AutomationRemoteDataSource].
final automationRemoteDataSourceProvider =
    Provider<AutomationRemoteDataSource>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  return AutomationRemoteDataSourceImpl(apiClient: apiClient);
});

/// Remote data source contract for CompozyOS automation and scheduler endpoints.
abstract class AutomationRemoteDataSource {
  Future<List<AutomationJobDto>> getJobs({bool allWorkspaces = true});
  Future<AutomationJobDto> getJobDetails(String id);
  Future<List<AutomationRunDto>> getJobRuns(String id);
  Future<AutomationRunDto> triggerJob(String id);
  Future<List<AutomationRunDto>> getRuns({bool allWorkspaces = true});
  Future<AutomationRunDto> cancelRun(String id);
  Future<List<AutomationTriggerDto>> getTriggers({bool allWorkspaces = true});
  Future<SchedulerStatus> getSchedulerStatus();
}

/// Implementation of [AutomationRemoteDataSource] using [CompozyApiClient].
class AutomationRemoteDataSourceImpl implements AutomationRemoteDataSource {
  final CompozyApiClient apiClient;

  AutomationRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<AutomationJobDto>> getJobs({bool allWorkspaces = true}) async {
    final queryParams = <String, dynamic>{
      if (allWorkspaces) 'all_workspaces': 'true',
    };

    final response = await apiClient.get(
      '/api/automation/jobs',
      queryParameters: queryParams,
    );

    final rawList = response['jobs'] ?? response['items'] ?? response['data'];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) =>
              AutomationJobDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<AutomationJobDto> getJobDetails(String id) async {
    final response = await apiClient.get('/api/automation/jobs/$id');
    final rawJob = response['job'] ?? response;
    if (rawJob is Map) {
      return AutomationJobDto.fromJson(Map<String, dynamic>.from(rawJob));
    }
    throw FormatException('Invalid job payload for id: $id');
  }

  @override
  Future<List<AutomationRunDto>> getJobRuns(String id) async {
    final response = await apiClient.get('/api/automation/jobs/$id/runs');
    final rawList = response['runs'] ?? response['items'] ?? response['data'];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) =>
              AutomationRunDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<AutomationRunDto> triggerJob(String id) async {
    final response = await apiClient.post('/api/automation/jobs/$id/trigger');
    final rawRun = response['run'] ?? response;
    if (rawRun is Map) {
      return AutomationRunDto.fromJson(Map<String, dynamic>.from(rawRun));
    }
    throw FormatException('Invalid run payload after triggering job: $id');
  }

  @override
  Future<List<AutomationRunDto>> getRuns({bool allWorkspaces = true}) async {
    final queryParams = <String, dynamic>{
      if (allWorkspaces) 'all_workspaces': 'true',
    };

    final response = await apiClient.get(
      '/api/automation/runs',
      queryParameters: queryParams,
    );

    final rawList = response['runs'] ?? response['items'] ?? response['data'];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) =>
              AutomationRunDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<AutomationRunDto> cancelRun(String id) async {
    final response = await apiClient.post('/api/automation/runs/$id/cancel');
    final rawRun = response['run'] ?? response;
    if (rawRun is Map) {
      return AutomationRunDto.fromJson(Map<String, dynamic>.from(rawRun));
    }
    throw FormatException('Invalid run payload after canceling run: $id');
  }

  @override
  Future<List<AutomationTriggerDto>> getTriggers({
    bool allWorkspaces = true,
  }) async {
    final queryParams = <String, dynamic>{
      if (allWorkspaces) 'all_workspaces': 'true',
    };

    final response = await apiClient.get(
      '/api/automation/triggers',
      queryParameters: queryParams,
    );

    final rawList =
        response['triggers'] ?? response['items'] ?? response['data'];
    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) =>
              AutomationTriggerDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const [];
  }

  @override
  Future<SchedulerStatus> getSchedulerStatus() async {
    final response = await apiClient.get('/api/scheduler');
    return SchedulerStatus.fromJson(response);
  }
}
