import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/presentation/app_shell.dart';
import 'core/theme/compozy_theme.dart';

void main() {
  runApp(const ProviderScope(child: CompozyApp()));
}

/// Main Compozy application entry widget.
class CompozyApp extends StatelessWidget {
  const CompozyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compozy',
      debugShowCheckedModeBanner: false,
      theme: CompozyTheme.darkTheme,
      home: const AppNavigationShell(),
    );
  }
}

/// Backward compatibility alias.
typedef MyApp = CompozyApp;
