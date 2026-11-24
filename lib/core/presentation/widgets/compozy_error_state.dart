import 'package:material_ui/material_ui.dart';

import '../../theme/compozy_theme.dart';

/// Friendly error surface. NEVER renders raw exception text: `message` is human
/// copy; optional `details` is shown collapsed behind a "Details" disclosure.
class CompozyErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String retryLabel;

  const CompozyErrorState({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);

    return Semantics(
      label: 'Error: $title. $message',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.line, width: 1),
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    size: 28,
                    color: palette.danger,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.fgStrong,
                  fontSize: textScaler.scale(16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: textScaler.scale(13),
                    height: 1.4,
                  ),
                ),
              ),
              if (details != null && details!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailsDisclosure(details: details!),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.primaryInk,
                    elevation: 0,
                    minimumSize: const Size(88, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: CompozyRadius.pill,
                    ),
                  ),
                  child: Text(
                    retryLabel,
                    style: TextStyle(
                      fontSize: textScaler.scale(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsDisclosure extends StatefulWidget {
  final String details;

  const _DetailsDisclosure({required this.details});

  @override
  State<_DetailsDisclosure> createState() => _DetailsDisclosureState();
}

class _DetailsDisclosureState extends State<_DetailsDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: CompozyRadius.input,
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Hide Details' : 'View Details',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
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
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: SelectableText(
                widget.details,
                style: TextStyle(
                  color: palette.subtle,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
