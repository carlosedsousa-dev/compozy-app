import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/health_checker.dart';
import '../../../../core/theme/compozy_theme.dart';

/// Provider for checking connection health against CompozyOS daemon.
final connectionStatusProvider = FutureProvider<bool>((ref) async {
  final healthChecker = ref.watch(healthCheckerProvider);
  return healthChecker.checkHealth();
});

/// Connection banner/badge widget showing daemon connectivity state.
/// Supports both compact pill mode (for Top AppBar) and full banner mode.
class ConnectionBanner extends ConsumerWidget {
  final bool? isOnline;
  final VoidCallback? onRetry;
  final bool compact;
  final String? errorMessage;

  const ConnectionBanner({
    super.key,
    this.isOnline,
    this.onRetry,
    this.compact = false,
    this.errorMessage,
  });

  const ConnectionBanner.compact({
    super.key,
    this.isOnline,
    this.onRetry,
    this.errorMessage,
  }) : compact = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If explicit isOnline is provided, use it; otherwise read provider.
    final bool resolvedOnline;
    if (isOnline != null) {
      resolvedOnline = isOnline!;
    } else {
      final asyncStatus = ref.watch(connectionStatusProvider);
      resolvedOnline = asyncStatus.value ?? false;
    }

    if (compact) {
      return _buildCompact(context, ref, resolvedOnline);
    }

    return _buildFullBanner(context, ref, resolvedOnline);
  }

  Widget _buildCompact(BuildContext context, WidgetRef ref, bool online) {
    final palette = context.palette;
    final statusColor = online ? palette.success : palette.danger;
    final label = online ? 'online' : 'offline';

    final pillWidget = Container(
      key: Key(online ? 'connection_pill_online' : 'connection_pill_offline'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (online) {
      return Semantics(
        label: 'Daemon connected (online)',
        child: pillWidget,
      );
    }

    return Semantics(
      label: 'Daemon disconnected (offline). Tap to retry connection.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: CompozyRadius.pill,
          onTap: () {
            if (onRetry != null) {
              onRetry!();
            }
            ref.invalidate(connectionStatusProvider);
          },
          child: pillWidget,
        ),
      ),
    );
  }

  Widget _buildFullBanner(BuildContext context, WidgetRef ref, bool online) {
    final palette = context.palette;

    if (online) {
      return Container(
        key: const Key('connection_banner_online'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: palette.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connected',
              style: TextStyle(
                color: palette.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(online)',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Offline / error banner
    return Container(
      key: const Key('connection_banner_offline'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: palette.danger, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: palette.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Disconnected',
                      style: TextStyle(
                        color: palette.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(offline)',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  errorMessage ??
                      'Daemon unreachable at http://localhost:2123',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const Key('connection_retry_button'),
            onPressed: () {
              if (onRetry != null) {
                onRetry!();
              }
              ref.invalidate(connectionStatusProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.primaryInk,
              elevation: 0,
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: CompozyRadius.pill,
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
