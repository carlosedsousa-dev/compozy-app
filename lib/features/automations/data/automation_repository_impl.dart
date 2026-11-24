import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/automation_job.dart';
import '../domain/models/automation_run.dart';
import '../domain/models/automation_trigger.dart';
import '../domain/models/scheduler_status.dart';
import '../domain/repositories/automation_repository.dart';
import 'sources/automation_remote_data_source.dart';

export '../domain/models/automation_job.dart';
export '../domain/models/automation_run.dart';
export '../domain/models/automation_trigger.dart';
export '../domain/models/scheduler_status.dart';
export '../domain/repositories/automation_repository.dart';
export 'sources/automation_remote_data_source.dart';

/// Riverpod provider for [AutomationRepository].
final automationRepositoryProvider = Provider<AutomationRepository>((ref) {
  final remoteDataSource = ref.watch(automationRemoteDataSourceProvider);
  return AutomationRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Riverpod provider to fetch all scheduled automation jobs.
final automationJobsProvider = FutureProvider<List<AutomationJob>>((ref) async {
  final repository = ref.watch(automationRepositoryProvider);
  return repository.getJobs(allWorkspaces: true);
});

/// Riverpod provider to fetch run history for a specific job.
final automationJobRunsProvider =
    FutureProvider.family<List<AutomationRun>, String>((ref, jobId) async {
  final repository = ref.watch(automationRepositoryProvider);
  return repository.getJobRuns(jobId);
});

/// Riverpod provider to fetch event/webhook automation triggers.
final automationTriggersProvider =
    FutureProvider<List<AutomationTrigger>>((ref) async {
  final repository = ref.watch(automationRepositoryProvider);
  return repository.getTriggers(allWorkspaces: true);
});

/// Riverpod provider to fetch scheduler status and diagnostics.
final automationSchedulerProvider =
    FutureProvider<SchedulerStatus>((ref) async {
  final repository = ref.watch(automationRepositoryProvider);
  return repository.getSchedulerStatus();
});

/// Riverpod provider for active automations tab segment:
/// 0 = Scheduled Jobs, 1 = Event Triggers.
final automationSegmentProvider = StateProvider<int>((ref) => 0);

/// Implementation of [AutomationRepository] coordinating with [AutomationRemoteDataSource].
class AutomationRepositoryImpl implements AutomationRepository {
  final AutomationRemoteDataSource remoteDataSource;

  AutomationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AutomationJob>> getJobs({bool allWorkspaces = true}) async {
    final dtos = await remoteDataSource.getJobs(allWorkspaces: allWorkspaces);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<AutomationJob> getJobDetails(String id) async {
    final dto = await remoteDataSource.getJobDetails(id);
    return dto.toDomain();
  }

  @override
  Future<List<AutomationRun>> getJobRuns(String id) async {
    final dtos = await remoteDataSource.getJobRuns(id);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<AutomationRun> triggerJob(String id) async {
    final dto = await remoteDataSource.triggerJob(id);
    return dto.toDomain();
  }

  @override
  Future<List<AutomationRun>> getRuns({bool allWorkspaces = true}) async {
    final dtos = await remoteDataSource.getRuns(allWorkspaces: allWorkspaces);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<AutomationRun> cancelRun(String id) async {
    final dto = await remoteDataSource.cancelRun(id);
    return dto.toDomain();
  }

  @override
  Future<List<AutomationTrigger>> getTriggers({
    bool allWorkspaces = true,
  }) async {
    final dtos =
        await remoteDataSource.getTriggers(allWorkspaces: allWorkspaces);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<SchedulerStatus> getSchedulerStatus() async {
    return remoteDataSource.getSchedulerStatus();
  }
}
