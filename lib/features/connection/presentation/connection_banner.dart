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
    final statusColor = online ? CompozyColors.success : CompozyColors.danger;
    final label = online ? 'online' : 'offline';

    return Container(
      key: Key(online ? 'connection_pill_online' : 'connection_pill_offline'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: CompozyColors.line, width: 1),
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
  }

  Widget _buildFullBanner(BuildContext context, WidgetRef ref, bool online) {
    if (online) {
      return Container(
        key: const Key('connection_banner_online'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: CompozyColors.surface2,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: CompozyColors.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: CompozyColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Connected',
              style: TextStyle(
                color: CompozyColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '(online)',
              style: TextStyle(
                color: CompozyColors.muted,
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
        color: CompozyColors.canvas,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: CompozyColors.danger, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: CompozyColors.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      'Disconnected',
                      style: TextStyle(
                        color: CompozyColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '(offline)',
                      style: TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  errorMessage ??
                      'Daemon unreachable at http://localhost:2123',
                  style: const TextStyle(
                    color: CompozyColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('connection_retry_button'),
            onPressed: () {
              if (onRetry != null) {
                onRetry!();
              }
              ref.invalidate(connectionStatusProvider);
            },
            style: TextButton.styleFrom(
              foregroundColor: CompozyColors.fgStrong,
              backgroundColor: CompozyColors.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: const RoundedRectangleBorder(
                borderRadius: CompozyRadius.pill,
                side: BorderSide(color: CompozyColors.line),
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
