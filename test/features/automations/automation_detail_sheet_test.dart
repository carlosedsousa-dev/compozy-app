import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/network/api_exceptions.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/automations/data/automation_repository_impl.dart';
import 'package:compozy_app/features/automations/presentation/automation_detail_sheet.dart';

class FakeAutomationRepository implements AutomationRepository {
  final Future<AutomationRun> Function(String id)? onTriggerJob;
  final Future<AutomationRun> Function(String id)? onCancelRun;
  final List<AutomationRun> runs;

  FakeAutomationRepository({
    this.onTriggerJob,
    this.onCancelRun,
    this.runs = const [],
  });

  @override
  Future<AutomationRun> triggerJob(String id) async {
    if (onTriggerJob != null) {
      return onTriggerJob!(id);
    }
    return AutomationRun(id: 'run_triggered', status: 'scheduled');
  }

  @override
  Future<AutomationRun> cancelRun(String id) async {
    if (onCancelRun != null) {
      return onCancelRun!(id);
    }
    return AutomationRun(id: id, status: 'canceled');
  }

  @override
  Future<List<AutomationRun>> getJobRuns(String id) async {
    return runs;
  }

  @override
  Future<AutomationJob> getJobDetails(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<AutomationJob>> getJobs({bool allWorkspaces = true}) async {
    return [];
  }

  @override
  Future<List<AutomationRun>> getRuns({bool allWorkspaces = true}) async {
    return runs;
  }

  @override
  Future<SchedulerStatus> getSchedulerStatus() async {
    return const SchedulerStatus();
  }

  @override
  Future<List<AutomationTrigger>> getTriggers({bool allWorkspaces = true}) async {
    return [];
  }
}

void main() {
  const testJob = AutomationJob(
    id: 'job_42',
    name: 'Daily standup synthesis',
    agentName: 'dispatcher',
    prompt:
        'This is a detailed and long prompt explaining how to inspect all open pull requests, compile activity from the past 24 hours, and produce a bulleted summary for the team in the general channel.',
    enabled: true,
    targetKind: 'agent',
    schedule: ScheduleSpec(expr: '0 9 * * 1-5'),
    retry: RetryConfig(strategy: 'backoff', maxRetries: 3, baseDelay: '10s'),
    fireLimit: FireLimitConfig(max: 10, window: '1h'),
  );

  final testRuns = [
    AutomationRun(
      id: 'run_active',
      jobId: 'job_42',
      status: 'running',
      attempt: 1,
      startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    AutomationRun(
      id: 'run_done',
      jobId: 'job_42',
      status: 'completed',
      attempt: 1,
      startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      endedAt: DateTime.now().subtract(const Duration(hours: 1, seconds: -45)),
    ),
  ];

  Widget createWidgetUnderTest({
    required AutomationRepository repository,
    AutomationJob job = testJob,
    List<AutomationRun>? runs,
  }) {
    final runsList = runs ?? testRuns;

    return ProviderScope(
      overrides: [
        automationRepositoryProvider.overrideWithValue(repository),
        automationJobRunsProvider(job.id).overrideWith((ref) => Future.value(runsList)),
        automationJobsProvider.overrideWith((ref) => Future.value([job])),
      ],
      child: MaterialApp(
        theme: CompozyTheme.darkTheme,
        home: Scaffold(
          body: AutomationDetailSheet(job: job),
        ),
      ),
    );
  }

  group('AutomationDetailSheet', () {
    testWidgets('renders configuration, collapsible prompt, and policies', (tester) async {
      final fakeRepo = FakeAutomationRepository();

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.text('Daily standup synthesis'), findsOneWidget);
      expect(find.text('Agent: dispatcher'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byKey(const Key('run_now_action_button')), findsOneWidget);

      // Policies
      expect(find.text('Every weekday at 09:00 (0 9 * * 1-5)'), findsOneWidget);
      expect(find.text('Backoff, up to 3 retries (10s base)'), findsOneWidget);
      expect(find.text('Max 10 runs / 1h'), findsOneWidget);

      // Collapsible prompt toggle
      expect(find.byKey(const Key('toggle_prompt_expand_button')), findsOneWidget);
      expect(find.text('Show full prompt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle_prompt_expand_button')));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('Run now success path triggers execution and shows snackbar feedback', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int triggerCount = 0;
      final completer = Completer<AutomationRun>();
      final fakeRepo = FakeAutomationRepository(
        onTriggerJob: (id) async {
          triggerCount++;
          expect(id, 'job_42');
          return completer.future;
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('run_now_action_button')));
      await tester.pump();

      // In flight state: progress indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      completer.complete(AutomationRun(id: 'new_run', status: 'scheduled'));
      await tester.pumpAndSettle();

      expect(triggerCount, 1);
      expect(find.text('Automation run triggered successfully'), findsOneWidget);
    });

    testWidgets('Run now failure path shows error snackbar with api message', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAutomationRepository(
        onTriggerJob: (id) async {
          throw CompozyApiException(message: 'daemon overloaded', statusCode: 503);
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('run_now_action_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to trigger run: daemon overloaded'), findsOneWidget);
    });

    testWidgets('renders run history with status badges and durations', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAutomationRepository();

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job_run_row_run_active')), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Duration: In progress'), findsOneWidget);

      expect(find.byKey(const Key('job_run_row_run_done')), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Duration: 45s'), findsOneWidget);
    });

    testWidgets('Cancel run action requires confirmation and cancels run on confirm', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int cancelCount = 0;
      final fakeRepo = FakeAutomationRepository(
        onCancelRun: (id) async {
          cancelCount++;
          expect(id, 'run_active');
          return AutomationRun(id: id, status: 'canceled');
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      // Tap cancel on active run
      await tester.tap(find.byKey(const Key('cancel_run_button_run_active')));
      await tester.pumpAndSettle();

      // Confirmation dialog should be presented
      expect(find.text('Cancel Run'), findsNWidgets(2)); // Title and confirm button
      expect(
        find.text('Are you sure you want to cancel this automation run? This will stop execution.'),
        findsOneWidget,
      );

      // Dismiss dialog with Keep Running
      await tester.tap(find.text('Keep Running'));
      await tester.pumpAndSettle();

      expect(cancelCount, 0); // Not cancelled

      // Tap cancel again and confirm
      await tester.tap(find.byKey(const Key('cancel_run_button_run_active')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_cancel_run_button')));
      await tester.pumpAndSettle();

      expect(cancelCount, 1);
      expect(find.text('Run cancelled'), findsOneWidget);
    });

    testWidgets('Cancel run failure shows error snackbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeAutomationRepository(
        onCancelRun: (id) async {
          throw CompozyApiException(message: 'run already finished');
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(repository: fakeRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel_run_button_run_active')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_cancel_run_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to cancel run: run already finished'), findsOneWidget);
    });
  });
}
