import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/connection/presentation/connection_banner.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../settings/settings_repository.dart';
import '../theme/compozy_theme.dart';
import '../theme/theme_mode_toggle.dart';
import 'compozy_feedback.dart';

/// Modal bottom sheet surface presenting workspace identity, connection health,
/// theme mode preferences, and navigation access to SettingsScreen.
class WorkspaceMenuSheet extends ConsumerWidget {
  final String workspaceName;
  final String? workspaceId;

  const WorkspaceMenuSheet({
    super.key,
    required this.workspaceName,
    this.workspaceId,
  });

  /// Presents the [WorkspaceMenuSheet] as a theme-aware modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String workspaceName,
    String? workspaceId,
  }) {
    compozyHaptic();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WorkspaceMenuSheet(
        workspaceName: workspaceName,
        workspaceId: workspaceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(settingsProvider);

    final resolvedWorkspaceId = workspaceId ??
        (settings.activeWorkspaceId != null &&
                settings.activeWorkspaceId!.trim().isNotEmpty
            ? settings.activeWorkspaceId!.trim()
            : (workspaceName == 'compozy-app'
                ? 'ws_3e99e4fe517eb344'
                : 'ws_${workspaceName.toLowerCase()}'));

    return Container(
      key: const Key('workspace_menu_sheet'),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: palette.line, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle affordance
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: palette.lineStrong,
                    borderRadius: CompozyRadius.pill,
                  ),
                ),
              ),

              // 1. Workspace identity: name + id (monospace, muted)
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.surface2,
                      borderRadius: CompozyRadius.input,
                      border: Border.all(color: palette.line, width: 1),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.workspaces_outlined,
                        size: 18,
                        color: palette.fgStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspaceName,
                          style: TextStyle(
                            color: palette.fgStrong,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          resolvedWorkspaceId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: palette.muted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: palette.lineSoft),
              const SizedBox(height: 16),

              // 2. Connection state (online/offline)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connection',
                    style: TextStyle(
                      color: palette.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const ConnectionBanner.compact(),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: palette.lineSoft),
              const SizedBox(height: 16),

              // 3. Theme selector using ThemeModeToggle.segmented
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ThemeModeToggle.segmented(),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: palette.lineSoft),
              const SizedBox(height: 12),

              // 4. Settings row that closes sheet and pushes SettingsScreen
              Semantics(
                label: 'Open Settings',
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('workspace_menu_settings_button'),
                    borderRadius: CompozyRadius.input,
                    onTap: () {
                      compozyHaptic();
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (routeContext) {
                            final routePalette = routeContext.palette;
                            return Scaffold(
                              backgroundColor: routePalette.desk,
                              appBar: AppBar(
                                backgroundColor: routePalette.canvas,
                                elevation: 0,
                                leading: IconButton(
                                  key: const Key('settings_back_button'),
                                  icon: Icon(Icons.arrow_back, color: routePalette.fg),
                                  tooltip: 'Back',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () {
                                    compozyHaptic();
                                    Navigator.of(routeContext).pop();
                                  },
                                ),
                                title: Text(
                                  'Settings',
                                  style: TextStyle(
                                    color: routePalette.fgStrong,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                bottom: PreferredSize(
                                  preferredSize: const Size.fromHeight(1),
                                  child: Container(color: routePalette.line, height: 1),
                                ),
                              ),
                              body: const SettingsScreen(),
                            );
                          },
                        ),
                      );
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 20, color: palette.fg),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Settings',
                                style: TextStyle(
                                  color: palette.fgStrong,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
