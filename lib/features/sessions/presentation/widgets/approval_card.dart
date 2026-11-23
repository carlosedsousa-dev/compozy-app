import 'dart:convert';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';

/// Human-in-the-Loop decision & permission approval card widget.
/// Strictly adheres to Compozy design tokens:
/// - Distinct card with 1px solid border (#E8572A at 30% alpha or #262626)
/// - "Needs you" banner container with #E8572A at 12% alpha and 1px #E8572A at 30% alpha border
/// - Solid 8x8dp #E8572A attention dot
/// - Tool call name and description in clean typography
/// - Primary action: Strictly monochrome inverted pill (#F5F5F5 bg, #0A0A0A bold text) for "Approve"
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

  Widget _buildNeedsYouBanner() {
    return Container(
      key: const Key('approval_card_needs_you_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CompozyColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: CompozyColors.accent.withValues(alpha: 0.30),
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
            decoration: const BoxDecoration(
              color: CompozyColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Needs you',
            style: TextStyle(
              color: CompozyColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolHeader() {
    if (toolName == null || toolName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        const Icon(
          Icons.terminal,
          size: 13,
          color: CompozyColors.muted,
        ),
        const SizedBox(width: 6),
        Text(
          'tool: $toolName',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: CompozyColors.fgStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      description,
      style: const TextStyle(
        color: CompozyColors.fg,
        fontSize: 13,
        height: 1.45,
      ),
    );
  }

  Widget _buildDetails() {
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
        color: CompozyColors.desk,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: SelectableText(
        formatted,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: CompozyColors.muted,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (isApproved != null) {
      return _buildResolvedBadge(isApproved!);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildRejectButton(),
        const SizedBox(width: 10),
        _buildApproveButton(),
      ],
    );
  }

  Widget _buildRejectButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('approval_card_reject_button'),
        borderRadius: CompozyRadius.pill,
        onTap: isProcessing
            ? null
            : () {
                onReject?.call();
                onDecision?.call(false);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: CompozyRadius.pill,
            border: Border.all(
              color: const Color(0xFF383838),
              width: 1,
            ),
          ),
          child: const Text(
            'Reject',
            style: TextStyle(
              color: CompozyColors.fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApproveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('approval_card_approve_button'),
        borderRadius: CompozyRadius.pill,
        onTap: isProcessing
            ? null
            : () {
                onApprove?.call();
                onDecision?.call(true);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: const BoxDecoration(
            color: CompozyColors.primary,
            borderRadius: CompozyRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CompozyColors.primaryInk,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Text(
                'Approve',
                style: TextStyle(
                  color: CompozyColors.primaryInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResolvedBadge(bool approved) {
    return Container(
      key: Key('approval_card_resolved_${approved ? 'approved' : 'rejected'}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: approved
            ? CompozyColors.success.withValues(alpha: 0.12)
            : CompozyColors.danger.withValues(alpha: 0.12),
        borderRadius: CompozyRadius.pill,
        border: Border.all(
          color: approved
              ? CompozyColors.success.withValues(alpha: 0.4)
              : CompozyColors.danger.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            approved ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: approved ? CompozyColors.success : CompozyColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            approved ? 'Approved' : 'Rejected',
            style: TextStyle(
              color: approved ? CompozyColors.success : CompozyColors.danger,
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CompozyColors.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(
          color: CompozyColors.accent.withValues(alpha: 0.30),
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
              _buildNeedsYouBanner(),
              if (title != null && title!.isNotEmpty)
                Text(
                  title!,
                  style: const TextStyle(
                    color: CompozyColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (toolName != null && toolName!.isNotEmpty) ...[
            _buildToolHeader(),
            const SizedBox(height: 8),
          ],
          _buildDescription(),
          if (details != null) ...[
            const SizedBox(height: 10),
            _buildDetails(),
          ],
          const SizedBox(height: 14),
          _buildActionButtons(),
        ],
      ),
    );
  }
}
