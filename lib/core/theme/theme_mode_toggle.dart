import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../settings/settings_repository.dart';
import 'compozy_theme.dart';

/// Interactive toggle allowing users to switch between Compozy Dark Mode,
/// Light Mode, or System preference.
///
/// Supports both a compact icon action (for top app bars and headers)
/// and a segmented selector (for settings screens).
class ThemeModeToggle extends ConsumerWidget {
  final bool isSegmented;
  final ValueChanged<ThemeMode>? onThemeChanged;

  const ThemeModeToggle({
    super.key,
    this.isSegmented = false,
    this.onThemeChanged,
  });

  const ThemeModeToggle.compact({
    super.key,
    this.onThemeChanged,
  }) : isSegmented = false;

  const ThemeModeToggle.segmented({
    super.key,
    this.onThemeChanged,
  }) : isSegmented = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentMode = settings.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isSegmented) {
      return _buildSegmentedSelector(context, ref, currentMode, isDark);
    }

    return _buildCompactToggle(context, ref, currentMode, isDark);
  }

  Widget _buildCompactToggle(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final isCurrentlyLight = currentMode == ThemeMode.light ||
        (currentMode == ThemeMode.system && !isDark);

    return IconButton(
      key: const Key('theme_mode_toggle'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: isCurrentlyLight ? 'Switch to Dark Mode' : 'Switch to Light Mode',
      icon: Icon(
        isCurrentlyLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        size: 18,
        color: isDark ? CompozyColors.fg : CompozyColorsLight.fg,
      ),
      onPressed: () {
        final nextMode = isCurrentlyLight ? ThemeMode.dark : ThemeMode.light;
        ref.read(settingsProvider.notifier).updateThemeMode(nextMode);
        onThemeChanged?.call(nextMode);
      },
    );
  }

  Widget _buildSegmentedSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final activeBg = isDark ? CompozyColors.primary : CompozyColorsLight.primary;
    final activeFg = isDark ? CompozyColors.primaryInk : CompozyColorsLight.primaryInk;
    final inactiveBg = isDark ? CompozyColors.surface2 : CompozyColorsLight.surface2;
    final inactiveFg = isDark ? CompozyColors.muted : CompozyColorsLight.muted;
    final borderColor = isDark ? CompozyColors.line : CompozyColorsLight.line;

    final options = [
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined, const Key('theme_option_dark')),
      (ThemeMode.light, 'Light', Icons.light_mode_outlined, const Key('theme_option_light')),
      (ThemeMode.system, 'System', Icons.brightness_auto_outlined, const Key('theme_option_system')),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: inactiveBg,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: options.map((option) {
          final mode = option.$1;
          final label = option.$2;
          final icon = option.$3;
          final key = option.$4;
          final isSelected = currentMode == mode;

          return Expanded(
            child: Material(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: CompozyRadius.input,
              child: InkWell(
                key: key,
                borderRadius: CompozyRadius.input,
                onTap: () {
                  ref.read(settingsProvider.notifier).updateThemeMode(mode);
                  onThemeChanged?.call(mode);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected ? activeFg : inactiveFg,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? activeFg : inactiveFg,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
