import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/scheduler_status.dart';

/// Health strip displaying CompozyOS scheduler daemon status:
/// paused state, queued runs, and attention counters.
class SchedulerHealthStrip extends StatelessWidget {
  final SchedulerStatus status;

  const SchedulerHealthStrip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    if (status.paused) {
      return Container(
        key: const Key('scheduler_paused_banner'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface2,
          borderRadius: CompozyRadius.card,
          border: Border.all(color: palette.warning, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.pause_circle_filled,
              size: 18,
              color: palette.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scheduler is paused',
                    style: TextStyle(
                      color: palette.fgStrong,
                      fontSize: textScaler.scale(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Scheduled automations will not trigger until the daemon scheduler is resumed.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: textScaler.scale(11),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('scheduler_active_strip'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active mint dot
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Scheduler Active',
                style: TextStyle(
                  color: palette.fg,
                  fontSize: textScaler.scale(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Queued runs pill
                  if (status.queuedRunCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: CompozyRadius.pill,
                        border: Border.all(color: palette.line, width: 1),
                      ),
                      child: Text(
                        'Queued: ${status.queuedRunCount}',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Needs attention badge (accent orange budget)
                  if (status.needsAttentionRunCount > 0)
                    Container(
                      key: const Key('scheduler_needs_attention_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: CompozyRadius.pill,
                        border: Border.all(color: palette.accent, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 11,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Needs attention: ${status.needsAttentionRunCount}',
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '0 queued',
                      style: TextStyle(
                        color: palette.subtle,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
