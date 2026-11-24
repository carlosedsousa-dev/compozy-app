import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/compozy_feedback.dart';
import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/automation_trigger.dart';
import 'automation_status_badge.dart';

/// Card component rendering an event or webhook trigger in the triggers tab.
class TriggerCard extends StatelessWidget {
  final AutomationTrigger trigger;

  const TriggerCard({
    super.key,
    required this.trigger,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final hasSlug = trigger.endpointSlug != null && trigger.endpointSlug!.isNotEmpty;

    return Semantics(
      label: 'Trigger ${trigger.name}, event ${trigger.event}, target ${trigger.targetDisplay}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: CompozyRadius.card,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top line: Name and Enabled quiet badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    trigger.name,
                    style: TextStyle(
                      color: palette.fgStrong,
                      fontSize: textScaler.scale(15),
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AutomationEnabledBadge(enabled: trigger.enabled),
              ],
            ),
            const SizedBox(height: 8),

            // Event line
            Row(
              children: [
                Icon(
                  Icons.bolt_outlined,
                  size: 13,
                  color: palette.info,
                ),
                const SizedBox(width: 6),
                Text(
                  trigger.event.isNotEmpty ? 'Event: ${trigger.event}' : 'Webhook Trigger',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: textScaler.scale(13),
                  ),
                ),
              ],
            ),

            // Endpoint slug container with copy button
            if (hasSlug) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surface2,
                  borderRadius: CompozyRadius.input,
                  border: Border.all(color: palette.lineSoft, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 13,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        trigger.endpointSlug!,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: palette.fg,
                          fontSize: textScaler.scale(11),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: Key('copy_slug_button_${trigger.id}'),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      iconSize: 16,
                      tooltip: 'Copy webhook slug',
                      icon: Icon(
                        Icons.copy,
                        color: palette.muted,
                        size: 15,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: trigger.endpointSlug!));
                        compozyHaptic();
                        showCompozySnack(
                          context,
                          'Webhook slug copied to clipboard',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom line: Target chip and last run outcome
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AutomationTargetChip(
                      label: trigger.targetDisplay,
                      isLoop: trigger.targetKind.toLowerCase() == 'loop',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (trigger.lastRun != null)
                  AutomationStatusBadge(
                    status: trigger.lastRun!.status,
                    label: 'Last: ${trigger.lastRun!.status}',
                  )
                else
                  Text(
                    'No fires yet',
                    style: TextStyle(
                      color: palette.subtle,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
