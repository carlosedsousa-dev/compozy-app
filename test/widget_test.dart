import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/main.dart';

void main() {
  testWidgets('AppNavigationShell renders mobile layout (< 600dp) with BottomNavigationBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((ref) => Future.value(const [])),
          connectionStatusProvider.overrideWith((ref) => Future.value(true)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workspace title in app bar
    expect(find.text('compozy-app'), findsOneWidget);

    // Verify BottomNavigationBar is used on mobile
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Verify nav destinations
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Loops'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Switch tab to Loops
    await tester.tap(find.text('Loops'));
    await tester.pumpAndSettle();
    expect(find.text('Loops Catalog'), findsOneWidget);

    // Switch tab to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Daemon Settings'), findsOneWidget);
  });

  testWidgets('AppNavigationShell renders desktop layout (>= 600dp) with NavigationRail', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionsProvider.overrideWith((ref) => Future.value(const [])),
          connectionStatusProvider.overrideWith((ref) => Future.value(true)),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify workspace title in app bar
    expect(find.text('compozy-app'), findsOneWidget);

    // Verify NavigationRail is used on desktop/tablet
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    // Verify rail destinations
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Loops'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
