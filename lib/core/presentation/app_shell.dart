import 'package:material_ui/material_ui.dart';

import '../theme/compozy_theme.dart';
import '../../features/connection/presentation/connection_banner.dart';
import '../../features/loops/presentation/loops_catalog_screen.dart';
import '../../features/sessions/presentation/sessions_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// Responsive application shell adapting between mobile (< 600dp)
/// and tablet/desktop (>= 600dp) environments, strictly mirroring
/// CompozyOS visual guidelines (lockup-dark.png, hero.jpg, board.jpg).
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

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const SessionsListScreen();
      case 1:
        return const LoopsCatalogScreen();
      case 2:
        return const SettingsScreen();
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
          return _buildMobileLayout();
        } else {
          return _buildDesktopLayout();
        }
      },
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        decoration: const BoxDecoration(
          color: CompozyColors.canvas,
          border: Border(
            bottom: BorderSide(color: Color(0xFF202020), width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // CompozyOS Brand Glyph (mirrors lockup-dark.png)
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
                    decoration: const BoxDecoration(
                      color: CompozyColors.canvas,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.workspaceName,
                style: const TextStyle(
                  color: CompozyColors.fgStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: CompozyColors.muted,
              ),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: ConnectionBanner.compact(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: CompozyColors.desk,
      appBar: _buildTopAppBar(),
      body: _buildBody(),
      bottomNavigationBar: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: CompozyColors.canvas,
          border: Border(
            top: BorderSide(color: Color(0xFF202020), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          key: const Key('app_bottom_nav_bar'),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: CompozyColors.canvas,
          selectedItemColor: CompozyColors.fgStrong,
          unselectedItemColor: CompozyColors.subtle,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
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
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.all_inclusive, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.all_inclusive),
              label: 'Loops',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Icon(Icons.tune, size: 20),
              ),
              activeIcon: _NavPill(icon: Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: CompozyColors.desk,
      appBar: _buildTopAppBar(),
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: CompozyColors.canvas,
              border: Border(
                right: BorderSide(color: Color(0xFF202020), width: 1),
              ),
            ),
            child: NavigationRail(
              key: const Key('app_navigation_rail'),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: CompozyColors.canvas,
              indicatorColor: CompozyColors.elevated,
              minWidth: 64,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble, color: CompozyColors.fgStrong),
                  label: Text('Sessions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.all_inclusive),
                  selectedIcon: Icon(Icons.all_inclusive, color: CompozyColors.fgStrong),
                  label: Text('Loops'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune),
                  selectedIcon: Icon(Icons.tune, color: CompozyColors.fgStrong),
                  label: Text('Settings'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: CompozyColors.elevated,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: const Color(0xFF2E2E2E), width: 1),
      ),
      child: Icon(
        icon,
        size: 18,
        color: CompozyColors.fgStrong,
      ),
    );
  }
}

/// Backward compatibility alias.
typedef AppShell = AppNavigationShell;
