import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/compozy_theme.dart';

/// Theme-aware snackbar. isError uses danger surface, default uses elevated card.
void showCompozySnack(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  compozyHaptic();

  final palette = context.palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isError ? palette.danger : palette.card;
  final fg = isError
      ? (isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF))
      : palette.fgStrong;
  final borderColor = isError ? palette.danger : palette.line;

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: CompozyRadius.card,
        side: BorderSide(color: borderColor, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: fg,
              onPressed: () {
                compozyHaptic();
                onAction?.call();
              },
            )
          : null,
    ),
  );
}

/// Light selection haptic; must be a no-op where unsupported (web/desktop) and never throw.
void compozyHaptic() {
  try {
    HapticFeedback.selectionClick();
  } catch (_) {
    // No-op where haptics are unsupported on web/desktop platforms.
  }
}
