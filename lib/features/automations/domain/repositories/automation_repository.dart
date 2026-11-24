import '../models/automation_job.dart';
import '../models/automation_run.dart';
import '../models/automation_trigger.dart';
import '../models/scheduler_status.dart';

abstract class AutomationRepository {
  /// Fetches scheduled automation jobs.
  Future<List<AutomationJob>> getJobs({bool allWorkspaces = true});

  /// Fetches a single automation job by ID.
  Future<AutomationJob> getJobDetails(String id);

  /// Fetches runs history for a specific job.
  Future<List<AutomationRun>> getJobRuns(String id);

  /// Forces an immediate manual execution of an automation job.
  Future<AutomationRun> triggerJob(String id);

  /// Fetches global automation runs.
  Future<List<AutomationRun>> getRuns({bool allWorkspaces = true});

  /// Cancels an in-progress or scheduled automation run.
  Future<AutomationRun> cancelRun(String id);

  /// Fetches event/webhook automation triggers.
  Future<List<AutomationTrigger>> getTriggers({bool allWorkspaces = true});

  /// Fetches scheduler health status.
  Future<SchedulerStatus> getSchedulerStatus();
}
