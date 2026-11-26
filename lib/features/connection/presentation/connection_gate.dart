import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/app_shell.dart';
import '../../../core/settings/settings_repository.dart';
import 'daemon_setup_screen.dart';

/// Gate widget placed at application root (`MaterialApp.home`).
///
/// Decides whether to route the user directly to [AppNavigationShell] or
/// require first-run daemon connectivity setup via [DaemonSetupScreen].
///
/// State matrix:
/// 1. `settings.hasConfirmedConnection == true` -> [AppNavigationShell] immediately,
///    even if the daemon is offline (the existing offline banner handles that).
/// 2. `settings.hasConfirmedConnection == false` -> [DaemonSetupScreen] on every platform.
///    First run always configures; no silent auto-confirm, no timeout race.
/// 3. "Continue offline" -> [AppNavigationShell] as gate-local bypass state without
///    marking connection confirmed in persistent settings.
class ConnectionGate extends ConsumerStatefulWidget {
  final Widget? shellOverride;
  final Widget? setupOverride;
  final Future<Map<String, dynamic>?> Function(String url)? testConnectionOverride;

  const ConnectionGate({
    super.key,
    this.shellOverride,
    this.setupOverride,
    this.testConnectionOverride,
  });

  @override
  ConsumerState<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends ConsumerState<ConnectionGate> {
  bool _bypassedOffline = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (settings.hasConfirmedConnection || _bypassedOffline) {
      return widget.shellOverride ?? const AppNavigationShell();
    }

    return widget.setupOverride ??
        DaemonSetupScreen(
          testConnectionOverride: widget.testConnectionOverride,
          onContinueOffline: () {
            setState(() {
              _bypassedOffline = true;
            });
          },
        );
  }
}
