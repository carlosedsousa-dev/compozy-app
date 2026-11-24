import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';

/// Semantic status badge for automation runs and states.
class AutomationStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const AutomationStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final normalized = status.toLowerCase();

    Color fgColor;
    Color dotColor;
    String text;

    switch (normalized) {
      case 'running':
        fgColor = palette.success;
        dotColor = palette.success;
        text = label ?? 'Running';
        break;
      case 'completed':
        fgColor = palette.fg;
        dotColor = palette.muted;
        text = label ?? 'Completed';
        break;
      case 'failed':
        fgColor = palette.danger;
        dotColor = palette.danger;
        text = label ?? 'Failed';
        break;
      case 'canceled':
      case 'cancelled':
        fgColor = palette.warning;
        dotColor = palette.warning;
        text = label ?? 'Canceled';
        break;
      case 'scheduled':
        fgColor = palette.info;
        dotColor = palette.info;
        text = label ?? 'Scheduled';
        break;
      case 'delegated':
        fgColor = palette.info;
        dotColor = palette.info;
        text = label ?? 'Delegated';
        break;
      default:
        fgColor = palette.muted;
        dotColor = palette.subtle;
        text = label ?? status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fgColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet badge showing whether an automation is enabled/active.
class AutomationEnabledBadge extends StatelessWidget {
  final bool enabled;

  const AutomationEnabledBadge({
    super.key,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Text(
        enabled ? 'Active' : 'Paused',
        style: TextStyle(
          color: enabled ? palette.fg : palette.muted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Pill chip identifying target agent or loop.
class AutomationTargetChip extends StatelessWidget {
  final String label;
  final bool isLoop;

  const AutomationTargetChip({
    super.key,
    required this.label,
    this.isLoop = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLoop ? Icons.all_inclusive : Icons.smart_toy_outlined,
            size: 11,
            color: palette.info,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.info,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
