import 'package:material_ui/material_ui.dart';

import '../theme/compozy_theme.dart';
import '../theme/theme_mode_toggle.dart';
import '../../features/agents/presentation/agents_screen.dart';
import '../../features/automations/presentation/automations_screen.dart';
import '../../features/connection/presentation/connection_banner.dart';
import '../../features/loops/presentation/loops_catalog_screen.dart';
import '../../features/sessions/presentation/sessions_list_screen.dart';
import 'compozy_feedback.dart';
import 'workspace_menu_sheet.dart';

/// Responsive application shell adapting between mobile (< 600dp)
/// and tablet/desktop (>= 600dp) environments, strictly mirroring
/// CompozyOS visual guidelines (lockup-dark.png, lockup-light.png, hero.jpg, board.jpg).
class AppNavigationShell extends StatefulWidget {
  final String workspaceName;

  const AppNavigationShell({
    super.key,
    this.workspaceName = 'compozy-app',
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openWorkspaceMenu() {
    compozyHaptic();
    WorkspaceMenuSheet.show(
      context,
      workspaceName: widget.workspaceName,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const SessionsListScreen();
      case 1:
        return const AgentsScreen();
      case 2:
        return const LoopsCatalogScreen();
      case 3:
        return const AutomationsScreen();
      default:
        return const SessionsListScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return _buildMobileLayout(constraints);
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final toolbarHeight = textScaler.scale(52.0).clamp(52.0, 72.0);

    return PreferredSize(
      preferredSize: Size.fromHeight(toolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: palette.canvas,
          border: Border(
            bottom: BorderSide(color: palette.line, width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: toolbarHeight,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 8,
          title: Semantics(
            label: 'Workspace menu for ${widget.workspaceName}',
            button: true,
            child: Tooltip(
              message: 'Open workspace menu',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('app_workspace_menu_button'),
                  borderRadius: CompozyRadius.input,
                  onTap: _openWorkspaceMenu,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // CompozyOS Brand Glyph (mirrors lockup-dark.png / lockup-light.png)
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Color(0xFF0070F3),
                                  Color(0xFF00DFD8),
                                  Color(0xFF0070F3),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: palette.canvas,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.workspaceName,
                              style: TextStyle(
                                color: palette.fgStrong,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: palette.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: const [
            ThemeModeToggle(key: Key('app_shell_theme_toggle')),
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: ConnectionBanner.compact(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final palette = context.palette;
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = textScaler.scale(1.0);
    final isNarrowOrScaled = constraints.maxWidth <= 340 || scale >= 1.25;
    final double labelFontSize = isNarrowOrScaled ? 9.5 : 11.0;
    final double labelLetterSpacing = isNarrowOrScaled ? -0.4 : 0.1;

    return Scaffold(
      backgroundColor: palette.desk,
      appBar: _buildTopAppBar(),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.canvas,
          border: Border(
            top: BorderSide(color: palette.line, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          key: const Key('app_bottom_nav_bar'),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: palette.canvas,
          selectedItemColor: palette.fgStrong,
          unselectedItemColor: palette.subtle,
          selectedFontSize: labelFontSize,
          unselectedFontSize: labelFontSize,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: labelLetterSpacing,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: labelLetterSpacing,
          ),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.chat_bubble_outline, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.chat_bubble),
              label: 'Sessions',
              tooltip: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.hub_outlined, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.hub),
              label: 'Agents',
              tooltip: 'Agents',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.all_inclusive, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.all_inclusive),
              label: 'Loops',
              tooltip: 'Loops',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.schedule_outlined, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.schedule),
              label: 'Automations',
              tooltip: 'Automations',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.desk,
      appBar: _buildTopAppBar(),
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: palette.canvas,
              border: Border(
                right: BorderSide(color: palette.line, width: 1),
              ),
            ),
            child: NavigationRail(
              key: const Key('app_navigation_rail'),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: palette.canvas,
              indicatorColor: palette.elevated,
              minWidth: 64,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble, color: palette.fgStrong),
                  label: const Text('Sessions'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub, color: palette.fgStrong),
                  label: const Text('Agents'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.all_inclusive),
                  selectedIcon: Icon(Icons.all_inclusive, color: palette.fgStrong),
                  label: const Text('Loops'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.schedule_outlined),
                  selectedIcon: Icon(Icons.schedule, color: palette.fgStrong),
                  label: const Text('Automations'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

/// Navigation indicator pill styling for active bottom navigation items.
class _NavPill extends StatelessWidget {
  final IconData icon;

  const _NavPill({required this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Icon(
        icon,
        size: 18,
        color: palette.fgStrong,
      ),
    );
  }
}

/// Backward compatibility alias.
typedef AppShell = AppNavigationShell;
