import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/cron_translator.dart';
import '../../domain/models/automation_job.dart';
import 'automation_status_badge.dart';

/// Card component rendering a single scheduled automation job in the catalog list.
class AutomationCard extends StatelessWidget {
  final AutomationJob job;
  final VoidCallback onTap;

  const AutomationCard({
    super.key,
    required this.job,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final scheduleText = CronTranslator.translate(job.schedule?.expr);

    return Semantics(
      button: true,
      label: 'Automation ${job.name}, scheduled $scheduleText, target ${job.targetDisplay}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('automation_card_${job.id}'),
          onTap: onTap,
          borderRadius: CompozyRadius.card,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: CompozyRadius.card,
              border: Border.all(color: palette.line, width: 1),
            ),
            child: ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row: Name and Enabled quiet badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            job.name,
                            style: TextStyle(
                              color: palette.fgStrong,
                              fontSize: textScaler.scale(15),
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AutomationEnabledBadge(enabled: job.enabled),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Middle line: Human readable schedule
                    if (scheduleText.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 13,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              scheduleText,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: textScaler.scale(13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Bottom row: Target chip and Last-run outcome
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AutomationTargetChip(
                              label: job.targetDisplay,
                              isLoop: job.isLoopTarget,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: job.lastRun != null
                              ? AutomationStatusBadge(
                                  status: job.lastRun!.status,
                                  label: 'Last: ${job.lastRun!.status}',
                                )
                              : Text(
                                  'No runs yet',
                                  style: TextStyle(
                                    color: palette.subtle,
                                    fontSize: 11,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
