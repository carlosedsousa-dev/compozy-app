import 'dart:convert';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/compozy_feedback.dart';
import '../../../../core/theme/compozy_theme.dart';

/// Human-in-the-Loop decision & permission approval card widget.
/// Strictly adheres to Compozy design tokens:
/// - Distinct card with 1px solid border (#E8572A at 30% alpha or #262626)
/// - "Needs you" banner container with #E8572A at 12% alpha and 1px #E8572A at 30% alpha border
/// - Solid 8x8dp #E8572A attention dot
/// - Tool call name and description in clean typography
/// - Primary action: Strictly monochrome inverted pill (#F5F5F5 bg, #0A0A0A bold text in dark) for "Approve"
/// - Secondary action: Outlined pill for "Reject"
///
/// Conforms to US-008.AC-1, US-008.AC-2, and REFERENCE_GUIDE.md.
class ApprovalCard extends StatelessWidget {
  final String? title;
  final String? toolName;
  final String description;
  final dynamic details;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final ValueChanged<bool>? onDecision;
  final bool? isApproved;
  final bool isProcessing;

  const ApprovalCard({
    super.key,
    this.title,
    this.toolName,
    required this.description,
    this.details,
    this.onApprove,
    this.onReject,
    this.onDecision,
    this.isApproved,
    this.isProcessing = false,
  });

  Widget _buildNeedsYouBanner(CompozyPalette palette) {
    return Container(
      key: const Key('approval_card_needs_you_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('approval_card_needs_you_dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Needs you',
            style: TextStyle(
              color: palette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolHeader(CompozyPalette palette) {
    if (toolName == null || toolName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Icon(
          Icons.terminal,
          size: 13,
          color: palette.muted,
        ),
        const SizedBox(width: 6),
        Text(
          'tool: $toolName',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: palette.fgStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(CompozyPalette palette) {
    return Text(
      description,
      style: TextStyle(
        color: palette.fg,
        fontSize: 13,
        height: 1.45,
      ),
    );
  }

  Widget _buildDetails(CompozyPalette palette) {
    if (details == null) return const SizedBox.shrink();
    String formatted;
    if (details is String) {
      formatted = details as String;
    } else {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        formatted = encoder.convert(details);
      } catch (_) {
        formatted = details.toString();
      }
    }
    if (formatted.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const Key('approval_card_details_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.desk,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: SelectableText(
        formatted,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: palette.muted,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CompozyPalette palette) {
    if (isApproved != null) {
      return _buildResolvedBadge(palette, isApproved!);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildRejectButton(context, palette),
        const SizedBox(width: 10),
        _buildApproveButton(context, palette),
      ],
    );
  }

  Widget _buildRejectButton(BuildContext context, CompozyPalette palette) {
    return Semantics(
      button: true,
      label: 'Reject',
      enabled: !isProcessing,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('approval_card_reject_button'),
          borderRadius: CompozyRadius.pill,
          onTap: isProcessing
              ? null
              : () {
                  compozyHaptic();
                  onReject?.call();
                  onDecision?.call(false);
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 80),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: CompozyRadius.pill,
                border: Border.all(
                  color: palette.lineStrong,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'Reject',
                  style: TextStyle(
                    color: isProcessing ? palette.subtle : palette.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApproveButton(BuildContext context, CompozyPalette palette) {
    return Semantics(
      button: true,
      label: 'Approve',
      enabled: !isProcessing,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('approval_card_approve_button'),
          borderRadius: CompozyRadius.pill,
          onTap: isProcessing
              ? null
              : () {
                  compozyHaptic();
                  onApprove?.call();
                  onDecision?.call(true);
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 80),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isProcessing ? palette.surface2 : palette.primary,
                borderRadius: CompozyRadius.pill,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProcessing) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.primaryInk,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      'Approve',
                      style: TextStyle(
                        color: isProcessing ? palette.subtle : palette.primaryInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildResolvedBadge(CompozyPalette palette, bool approved) {
    return Container(
      key: Key('approval_card_resolved_${approved ? 'approved' : 'rejected'}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: approved
            ? palette.success.withValues(alpha: 0.12)
            : palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(
          color: approved
              ? palette.success.withValues(alpha: 0.4)
              : palette.lineStrong,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.check_circle : Icons.cancel_outlined,
            size: 14,
            color: approved ? palette.success : palette.muted,
          ),
          const SizedBox(width: 6),
          Text(
            approved ? 'Approved' : 'Rejected',
            style: TextStyle(
              color: approved ? palette.success : palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNeedsYouBanner(palette),
              if (title != null && title!.isNotEmpty)
                Text(
                  title!,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (toolName != null && toolName!.isNotEmpty) ...[
            _buildToolHeader(palette),
            const SizedBox(height: 8),
          ],
          _buildDescription(palette),
          if (details != null) ...[
            const SizedBox(height: 10),
            _buildDetails(palette),
          ],
          const SizedBox(height: 14),
          _buildActionButtons(context, palette),
        ],
      ),
    );
  }
}
