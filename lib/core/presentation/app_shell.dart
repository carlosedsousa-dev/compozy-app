import 'package:material_ui/material_ui.dart';

import '../theme/compozy_theme.dart';
import '../../features/connection/presentation/connection_banner.dart';
import '../../features/sessions/presentation/sessions_list_screen.dart';

/// Responsive application shell adapting between mobile (< 600dp)
/// and tablet/desktop (>= 600dp) environments.
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
        return const _PlaceholderView(title: 'Loops Catalog');
      case 2:
        return const _PlaceholderView(title: 'Daemon Settings');
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
          color: CompozyColors.rail,
          border: Border(
            bottom: BorderSide(color: CompozyColors.line, width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.workspaceName,
                style: const TextStyle(
                  color: CompozyColors.fgStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
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
        decoration: const BoxDecoration(
          color: CompozyColors.rail,
          border: Border(
            top: BorderSide(color: CompozyColors.line, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          key: const Key('app_bottom_nav_bar'),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: CompozyColors.rail,
          selectedItemColor: CompozyColors.fgStrong,
          unselectedItemColor: CompozyColors.muted,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: _NavPill(icon: Icons.chat_bubble),
              label: 'Sessions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.all_inclusive),
              activeIcon: _NavPill(icon: Icons.all_inclusive),
              label: 'Loops',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune),
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
              color: CompozyColors.rail,
              border: Border(
                right: BorderSide(color: CompozyColors.line, width: 1),
              ),
            ),
            child: NavigationRail(
              key: const Key('app_navigation_rail'),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: CompozyColors.rail,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: const BoxDecoration(
        color: CompozyColors.elevated,
        borderRadius: CompozyRadius.pill,
      ),
      child: Icon(
        icon,
        size: 20,
        color: CompozyColors.fgStrong,
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String title;

  const _PlaceholderView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon in the next phase.',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias.
typedef AppShell = AppNavigationShell;
