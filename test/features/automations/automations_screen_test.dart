import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/automations/data/automation_repository_impl.dart';
import 'package:compozy_app/features/automations/presentation/automations_screen.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';

void main() {
  final testJobs = [
    const AutomationJob(
      id: 'job_daily',
      name: 'Daily workspace briefing',
      agentName: 'dispatcher',
      prompt: 'Review workspace activity and draft a summary.',
      enabled: true,
      targetKind: 'agent',
      schedule: ScheduleSpec(expr: '0 8 * * *'),
      retry: RetryConfig(strategy: 'none'),
      fireLimit: FireLimitConfig(max: 12, window: '1h'),
      lastRun: AutomationLastRun(
        id: 'run_1',
        status: 'completed',
      ),
    ),
    const AutomationJob(
      id: 'job_loop',
      name: 'Deliver phase pipeline',
      agentName: 'engineer',
      prompt: 'Execute all phases sequentially.',
      enabled: false,
      targetKind: 'loop',
      loopTarget: LoopTargetConfig(loopName: 'deliver-phases'),
      schedule: ScheduleSpec(expr: '0 9 * * 1-5'),
      retry: RetryConfig(strategy: 'backoff', maxRetries: 3, baseDelay: '5s'),
      fireLimit: FireLimitConfig(max: 5, window: '1h'),
      lastRun: AutomationLastRun(
        id: 'run_2',
        status: 'running',
      ),
    ),
  ];

  final testTriggers = [
    const AutomationTrigger(
      id: 'trig_01',
      name: 'GitHub Webhook Release',
      agentName: 'dispatcher',
      prompt: 'Analyze incoming release payload.',
      event: 'webhook',
      endpointSlug: 'release-webhook-slug',
      enabled: true,
    ),
  ];

  Widget createWidgetUnderTest(
    WidgetTester tester, {
    List<Override> overrides = const [],
    double textScale = 1.0,
    Size surfaceSize = const Size(390, 844),
  }) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: [
        connectionStatusProvider.overrideWith((ref) => Future.value(true)),
        ...overrides,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const AutomationsScreen(),
        ),
      ),
    );
  }

  group('AutomationsScreen', () {
    testWidgets('renders skeleton placeholders while loading', (tester) async {
      final completer = Completer<List<AutomationJob>>();

      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => completer.future),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      // Loading state visible
      expect(find.byKey(const Key('automations_loading_skeletons')), findsOneWidget);

      completer.complete(testJobs);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automations_loading_skeletons')), findsNothing);
      expect(find.byKey(const Key('automations_list_view')), findsOneWidget);
    });

    testWidgets('renders error state and retries on press', (tester) async {
      int fetchAttempts = 0;

      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) {
              fetchAttempts++;
              if (fetchAttempts == 1) {
                return Future.error('Daemon connection failed');
              }
              return Future.value(testJobs);
            }),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automations_error_state')), findsOneWidget);
      expect(find.text('Failed to load automations'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automations_error_state')), findsNothing);
      expect(find.byKey(const Key('automations_list_view')), findsOneWidget);
      expect(fetchAttempts, 2);
    });

    testWidgets('renders empty state that teaches when no automations exist', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value([])),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automations_empty_state')), findsOneWidget);
      expect(find.text('No automations configured'), findsOneWidget);
      expect(
        find.textContaining('compozy automation jobs create'),
        findsOneWidget,
      );
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('renders job cards with title, human schedule, target chip, and badges', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Daily workspace briefing'), findsOneWidget);
      expect(find.text('Every day at 08:00'), findsOneWidget);
      expect(find.text('Agent: dispatcher'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Last: completed'), findsOneWidget);

      expect(find.text('Deliver phase pipeline'), findsOneWidget);
      expect(find.text('Every weekday at 09:00'), findsOneWidget);
      expect(find.text('Loop: deliver-phases'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Last: running'), findsOneWidget);
    });

    testWidgets('renders paused scheduler banner when scheduler.paused is true', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(
                const SchedulerStatus(
                  paused: true,
                  queuedRunCount: 0,
                  needsAttentionRunCount: 0,
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scheduler_paused_banner')), findsOneWidget);
      expect(find.text('Scheduler is paused'), findsOneWidget);
      expect(
        find.textContaining('Scheduled automations will not trigger'),
        findsOneWidget,
      );
    });

    testWidgets('renders active scheduler strip with attention counter when active', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(
                const SchedulerStatus(
                  paused: false,
                  queuedRunCount: 3,
                  needsAttentionRunCount: 1,
                ),
              ),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scheduler_active_strip')), findsOneWidget);
      expect(find.text('Scheduler Active'), findsOneWidget);
      expect(find.text('Queued: 3'), findsOneWidget);
      expect(find.byKey(const Key('scheduler_needs_attention_badge')), findsOneWidget);
      expect(find.text('Needs attention: 1'), findsOneWidget);
    });

    testWidgets('switches to Triggers segment and shows trigger cards with copyable slug', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value(testTriggers)),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Tap Triggers tab
      await tester.tap(find.byKey(const Key('segment_triggers_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('triggers_list_view')), findsOneWidget);
      expect(find.text('GitHub Webhook Release'), findsOneWidget);
      expect(find.text('release-webhook-slug'), findsOneWidget);
      expect(find.byKey(const Key('copy_slug_button_trig_01')), findsOneWidget);
    });

    testWidgets('renders empty state in triggers tab when no triggers exist', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Switch to triggers tab
      await tester.tap(find.byKey(const Key('segment_triggers_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('triggers_empty_state')), findsOneWidget);
      expect(find.text('No event triggers'), findsOneWidget);
      expect(
        find.textContaining('compozy automation triggers create'),
        findsOneWidget,
      );
    });

    testWidgets('tapping job card opens detail bottom sheet', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationJobRunsProvider('job_daily').overrideWith((ref) => Future.value([])),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('automation_card_job_daily')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automation_details_bottom_sheet')), findsOneWidget);
      expect(find.byKey(const Key('run_now_action_button')), findsOneWidget);
    });

    testWidgets('renders responsive desktop layout (>=600dp) with GridView without overflow', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          tester,
          surfaceSize: const Size(1024, 768),
          textScale: 1.5,
          overrides: [
            automationJobsProvider.overrideWith((ref) => Future.value(testJobs)),
            automationTriggersProvider.overrideWith((ref) => Future.value([])),
            automationSchedulerProvider.overrideWith(
              (ref) => Future.value(const SchedulerStatus()),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('automations_grid_view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
