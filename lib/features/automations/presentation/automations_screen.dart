import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/widgets/compozy_empty_state.dart';
import '../../../core/presentation/widgets/compozy_error_state.dart';
import '../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';
import '../data/automation_repository_impl.dart';
import 'automation_detail_sheet.dart';
import 'widgets/automation_card.dart';
import 'widgets/scheduler_health_strip.dart';
import 'widgets/trigger_card.dart';

export 'automation_detail_sheet.dart';
export 'widgets/automation_card.dart';
export 'widgets/automation_status_badge.dart';
export 'widgets/scheduler_health_strip.dart';
export 'widgets/trigger_card.dart';

/// Screen displaying the CompozyOS Automations catalog, scheduler health diagnostics,
/// and event/webhook triggers with run execution controls.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final jobsAsync = ref.watch(automationJobsProvider);
    final triggersAsync = ref.watch(automationTriggersProvider);
    final schedulerAsync = ref.watch(automationSchedulerProvider);
    final activeSegment = ref.watch(automationSegmentProvider);
    final isOnline = ref.watch(connectionStatusProvider).value ?? true;

    return Scaffold(
      backgroundColor: palette.desk,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection banner when offline
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConnectionBanner(),
            ),

          // Header with Title and counts
          _buildHeader(context, jobsAsync, triggersAsync),

          // Scheduler Health Strip (Paused / Active / Queued / Needs Attention)
          schedulerAsync.maybeWhen(
            data: (status) => SchedulerHealthStrip(status: status),
            orElse: () => const SizedBox.shrink(),
          ),

          // Segment Selector (Scheduled Jobs vs Event Triggers)
          _buildSegmentBar(context, ref, activeSegment, jobsAsync, triggersAsync),

          // Main list content with Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('automations_refresh_indicator'),
              color: palette.fgStrong,
              backgroundColor: palette.card,
              onRefresh: () async {
                ref.invalidate(automationJobsProvider);
                ref.invalidate(automationTriggersProvider);
                ref.invalidate(automationSchedulerProvider);
                await Future.wait([
                  ref.read(automationJobsProvider.future),
                  ref.read(automationTriggersProvider.future),
                  ref.read(automationSchedulerProvider.future),
                ]);
              },
              child: activeSegment == 0
                  ? _buildJobsTab(context, ref, jobsAsync)
                  : _buildTriggersTab(context, ref, triggersAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<List<AutomationJob>> jobsAsync,
    AsyncValue<List<AutomationTrigger>> triggersAsync,
  ) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            'Automations',
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: textScaler.scale(16),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 8),
          jobsAsync.maybeWhen(
            data: (jobs) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surface2,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Text(
                '${jobs.length}',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentBar(
    BuildContext context,
    WidgetRef ref,
    int activeSegment,
    AsyncValue<List<AutomationJob>> jobsAsync,
    AsyncValue<List<AutomationTrigger>> triggersAsync,
  ) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    final scheduledCount = jobsAsync.maybeWhen(
      data: (jobs) => ' (${jobs.length})',
      orElse: () => '',
    );
    final triggersCount = triggersAsync.maybeWhen(
      data: (triggers) => ' (${triggers.length})',
      orElse: () => '',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.surface2,
          borderRadius: CompozyRadius.pill,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Row(
          children: [
            // Scheduled Segment
            Expanded(
              child: Semantics(
                button: true,
                selected: activeSegment == 0,
                label: 'Scheduled automations tab',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    key: const Key('segment_scheduled_button'),
                    borderRadius: CompozyRadius.pill,
                    onTap: () {
                      ref.read(automationSegmentProvider.notifier).state = 0;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: activeSegment == 0
                            ? palette.elevated
                            : Colors.transparent,
                        borderRadius: CompozyRadius.pill,
                        border: activeSegment == 0
                            ? Border.all(color: palette.lineStrong, width: 1)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Scheduled$scheduledCount',
                        style: TextStyle(
                          color: activeSegment == 0
                              ? palette.fgStrong
                              : palette.muted,
                          fontSize: textScaler.scale(13),
                          fontWeight: activeSegment == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Triggers Segment
            Expanded(
              child: Semantics(
                button: true,
                selected: activeSegment == 1,
                label: 'Event triggers tab',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    key: const Key('segment_triggers_button'),
                    borderRadius: CompozyRadius.pill,
                    onTap: () {
                      ref.read(automationSegmentProvider.notifier).state = 1;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: activeSegment == 1
                            ? palette.elevated
                            : Colors.transparent,
                        borderRadius: CompozyRadius.pill,
                        border: activeSegment == 1
                            ? Border.all(color: palette.lineStrong, width: 1)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Triggers$triggersCount',
                        style: TextStyle(
                          color: activeSegment == 1
                              ? palette.fgStrong
                              : palette.muted,
                          fontSize: textScaler.scale(13),
                          fontWeight: activeSegment == 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AutomationJob>> jobsAsync,
  ) {
    return jobsAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (error, _) => CompozyErrorState(
        key: const Key('automations_error_state'),
        title: 'Failed to load automations',
        message:
            'Unable to connect to the CompozyOS daemon to fetch scheduled automations.',
        details: error.toString(),
        onRetry: () => ref.invalidate(automationJobsProvider),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return CompozyEmptyState(
            key: const Key('automations_empty_state'),
            icon: Icons.auto_mode_outlined,
            title: 'No automations configured',
            message:
                'Automations run agents or loops on a recurring schedule. You can create them using the Compozy CLI (\'compozy automation jobs create\') or via the desktop app.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(automationJobsProvider),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final textScaler = MediaQuery.textScalerOf(context);
            final cardExtent = textScaler.scale(220.0).clamp(200.0, 480.0);

            if (isMobile) {
              return ListView.separated(
                key: const Key('automations_list_view'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: jobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return AutomationCard(
                    job: job,
                    onTap: () => _openJobDetails(context, job),
                  );
                },
              );
            } else {
              return GridView.builder(
                key: const Key('automations_grid_view'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 480,
                  mainAxisExtent: cardExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return AutomationCard(
                    job: job,
                    onTap: () => _openJobDetails(context, job),
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildTriggersTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AutomationTrigger>> triggersAsync,
  ) {
    return triggersAsync.when(
      loading: () => _buildLoadingSkeleton(context),
      error: (error, _) => CompozyErrorState(
        key: const Key('triggers_error_state'),
        title: 'Failed to load triggers',
        message:
            'Unable to connect to the CompozyOS daemon to fetch event triggers.',
        details: error.toString(),
        onRetry: () => ref.invalidate(automationTriggersProvider),
      ),
      data: (triggers) {
        if (triggers.isEmpty) {
          return CompozyEmptyState(
            key: const Key('triggers_empty_state'),
            icon: Icons.bolt_outlined,
            title: 'No event triggers',
            message:
                'Event triggers execute automations when webhooks or workspace events occur. You can register them via the CLI (\'compozy automation triggers create\') or desktop app.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(automationTriggersProvider),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final textScaler = MediaQuery.textScalerOf(context);
            final cardExtent = textScaler.scale(240.0).clamp(220.0, 520.0);

            if (isMobile) {
              return ListView.separated(
                key: const Key('triggers_list_view'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: triggers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final trigger = triggers[index];
                  return TriggerCard(trigger: trigger);
                },
              );
            } else {
              return GridView.builder(
                key: const Key('triggers_grid_view'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 480,
                  mainAxisExtent: cardExtent,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: triggers.length,
                itemBuilder: (context, index) {
                  final trigger = triggers[index];
                  return TriggerCard(trigger: trigger);
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return ListView.separated(
      key: const Key('automations_loading_skeletons'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final palette = context.palette;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: CompozyRadius.card,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CompozySkeleton(width: 140, height: 14),
                  CompozySkeleton(
                    width: 50,
                    height: 14,
                    borderRadius: BorderRadius.all(Radius.circular(9999)),
                  ),
                ],
              ),
              SizedBox(height: 12),
              CompozySkeleton(width: 220, height: 12),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CompozySkeleton(width: 80, height: 18),
                  CompozySkeleton(width: 70, height: 18),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openJobDetails(BuildContext context, AutomationJob job) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AutomationDetailSheet(job: job),
    );
  }
}
