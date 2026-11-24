import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../../../core/presentation/compozy_feedback.dart';
import '../../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../../core/theme/compozy_theme.dart';
import '../data/automation_repository_impl.dart';
import '../domain/cron_translator.dart';
import 'widgets/automation_status_badge.dart';

/// Modal bottom sheet displaying detailed automation configuration, full collapsible prompt,
/// retry/fire policies, run history, and action controls (Run now & Cancel run).
class AutomationDetailSheet extends ConsumerStatefulWidget {
  final AutomationJob job;

  const AutomationDetailSheet({
    super.key,
    required this.job,
  });

  @override
  ConsumerState<AutomationDetailSheet> createState() =>
      _AutomationDetailSheetState();
}

class _AutomationDetailSheetState extends ConsumerState<AutomationDetailSheet> {
  bool _promptExpanded = false;
  bool _isRunningNow = false;
  final Set<String> _cancellingRunIds = {};

  Future<void> _handleRunNow() async {
    if (_isRunningNow) return;

    setState(() {
      _isRunningNow = true;
    });

    try {
      final repository = ref.read(automationRepositoryProvider);
      await repository.triggerJob(widget.job.id);

      if (!mounted) return;
      compozyHaptic();
      showCompozySnack(context, 'Automation run triggered successfully');

      ref.invalidate(automationJobRunsProvider(widget.job.id));
      ref.invalidate(automationJobsProvider);
    } catch (e) {
      if (!mounted) return;
      compozyHaptic();
      final message =
          e is CompozyApiException ? e.message : 'Unable to trigger run.';
      showCompozySnack(context, 'Failed to trigger run: $message', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRunningNow = false;
        });
      }
    }
  }

  Future<void> _handleCancelRun(AutomationRun run) async {
    if (_cancellingRunIds.contains(run.id)) return;

    // Destructive action: show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: CompozyRadius.card,
            side: BorderSide(color: palette.line, width: 1),
          ),
          title: Text(
            'Cancel Run',
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this automation run? This will stop execution.',
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: palette.muted,
              ),
              child: const Text('Keep Running'),
            ),
            ElevatedButton(
              key: const Key('confirm_cancel_run_button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(88, 48),
                backgroundColor: palette.danger,
                foregroundColor: palette.primaryInk,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: CompozyRadius.pill,
                ),
              ),
              child: const Text(
                'Cancel Run',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _cancellingRunIds.add(run.id);
    });

    try {
      final repository = ref.read(automationRepositoryProvider);
      await repository.cancelRun(run.id);

      if (!mounted) return;
      compozyHaptic();
      showCompozySnack(context, 'Run cancelled');

      ref.invalidate(automationJobRunsProvider(widget.job.id));
      ref.invalidate(automationJobsProvider);
    } catch (e) {
      if (!mounted) return;
      compozyHaptic();
      final message =
          e is CompozyApiException ? e.message : 'Unable to cancel run.';
      showCompozySnack(context, 'Failed to cancel run: $message', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _cancellingRunIds.remove(run.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final runsAsync = ref.watch(automationJobRunsProvider(widget.job.id));
    final scheduleText = CronTranslator.translate(widget.job.schedule?.expr);

    return Container(
      key: const Key('automation_details_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: palette.line, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.lineStrong,
                  borderRadius: CompozyRadius.pill,
                ),
              ),
            ),

            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.job.name,
                          style: TextStyle(
                            color: palette.fgStrong,
                            fontSize: textScaler.scale(18),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AutomationTargetChip(
                              label: widget.job.targetDisplay,
                              isLoop: widget.job.isLoopTarget,
                            ),
                            const SizedBox(width: 6),
                            AutomationEnabledBadge(enabled: widget.job.enabled),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close_automation_details_button'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close,
                      color: palette.muted,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(color: palette.line, height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action button: Run now (Inverted monochrome pill)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('run_now_action_button'),
                        onPressed: _isRunningNow ? null : _handleRunNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.primaryInk,
                          disabledBackgroundColor:
                              palette.primary.withValues(alpha: 0.5),
                          disabledForegroundColor:
                              palette.primaryInk.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: CompozyRadius.pill,
                          ),
                        ),
                        child: _isRunningNow
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    palette.primaryInk,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                    color: palette.primaryInk,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Run now',
                                    style: TextStyle(
                                      color: palette.primaryInk,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prompt Section (Collapsible)
                    _buildPromptSection(context),
                    const SizedBox(height: 20),

                    // Schedule & Policies Section
                    _buildPoliciesSection(context, scheduleText),
                    const SizedBox(height: 24),

                    // Run History Section
                    _buildRunHistorySection(context, runsAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSection(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final prompt = widget.job.prompt.trim();

    if (prompt.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLongPrompt = prompt.length > 140;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROMPT',
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: CompozyRadius.input,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prompt,
                maxLines: _promptExpanded || !isLongPrompt ? null : 3,
                overflow: _promptExpanded || !isLongPrompt
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: textScaler.scale(13),
                  height: 1.4,
                ),
              ),
              if (isLongPrompt) ...[
                const SizedBox(height: 8),
                InkWell(
                  key: const Key('toggle_prompt_expand_button'),
                  borderRadius: CompozyRadius.input,
                  onTap: () {
                    setState(() {
                      _promptExpanded = !_promptExpanded;
                    });
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _promptExpanded ? 'Show less' : 'Show full prompt',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _promptExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: palette.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoliciesSection(BuildContext context, String scheduleText) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONFIGURATION',
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: CompozyRadius.input,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Column(
            children: [
              _buildConfigRow(
                context,
                label: 'Schedule',
                value: scheduleText.isNotEmpty
                    ? '$scheduleText (${widget.job.schedule?.expr ?? ''})'
                    : 'Manual trigger only',
              ),
              Divider(color: palette.lineSoft, height: 16),
              _buildConfigRow(
                context,
                label: 'Retry Policy',
                value: widget.job.retry.displayDescription,
              ),
              Divider(color: palette.lineSoft, height: 16),
              _buildConfigRow(
                context,
                label: 'Fire Limit',
                value: widget.job.fireLimit.displayDescription,
              ),
              Divider(color: palette.lineSoft, height: 16),
              _buildConfigRow(
                context,
                label: 'Scope',
                value: widget.job.scope.toUpperCase(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontSize: textScaler.scale(12),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: palette.fgStrong,
              fontSize: textScaler.scale(12),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunHistorySection(
    BuildContext context,
    AsyncValue<List<AutomationRun>> runsAsync,
  ) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RUN HISTORY',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            IconButton(
              key: const Key('refresh_job_runs_button'),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              iconSize: 16,
              tooltip: 'Refresh history',
              icon: Icon(
                Icons.refresh,
                size: 16,
                color: palette.muted,
              ),
              onPressed: () {
                compozyHaptic();
                ref.invalidate(automationJobRunsProvider(widget.job.id));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        runsAsync.when(
          loading: () => Column(
            children: const [
              CompozySkeleton(height: 52),
              SizedBox(height: 8),
              CompozySkeleton(height: 52),
            ],
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: CompozyRadius.input,
              border: Border.all(color: palette.line, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: palette.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to load history',
                    style: TextStyle(
                      color: palette.danger,
                      fontSize: textScaler.scale(12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(automationJobRunsProvider(widget.job.id)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: palette.fgStrong,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (runs) {
            if (runs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: palette.surface2,
                  borderRadius: CompozyRadius.input,
                  border: Border.all(color: palette.line, width: 1),
                ),
                child: Center(
                  child: Text(
                    'No run history recorded for this automation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: textScaler.scale(12),
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: runs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final run = runs[index];
                final isCancelling = _cancellingRunIds.contains(run.id);

                return Container(
                  key: Key('job_run_row_${run.id}'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: CompozyRadius.input,
                    border: Border.all(color: palette.line, width: 1),
                  ),
                  child: Row(
                    children: [
                      AutomationStatusBadge(status: run.status),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration: ${run.durationDisplay}',
                              style: TextStyle(
                                color: palette.fg,
                                fontSize: textScaler.scale(12),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (run.skipReason != null &&
                                run.skipReason!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Skipped: ${run.skipReason}',
                                  style: TextStyle(
                                    color: palette.warning,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (run.isCancelable) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          key: Key('cancel_run_button_${run.id}'),
                          onPressed:
                              isCancelling ? null : () => _handleCancelRun(run),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            foregroundColor: palette.danger,
                          ),
                          child: isCancelling
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.danger,
                                  ),
                                )
                              : Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: textScaler.scale(12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
