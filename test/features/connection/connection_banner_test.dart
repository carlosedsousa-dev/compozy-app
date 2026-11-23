import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/connection/presentation/connection_banner.dart';

void main() {
  group('testConnectionBanner (IT-001)', () {
    testWidgets('renders green when online with explicit parameter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConnectionBanner(isOnline: true),
            ),
          ),
        ),
      );

      // Verify connected / online text
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('(online)'), findsOneWidget);
      expect(find.byKey(const Key('connection_banner_online')), findsOneWidget);

      // Verify text color is success (green)
      final textWidget = tester.widget<Text>(find.text('Connected'));
      expect(textWidget.style?.color, CompozyColors.success);
    });

    testWidgets('renders red banner when offline with explicit parameter', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConnectionBanner(
                isOnline: false,
                onRetry: () {
                  retried = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify disconnected / offline text and error message
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('(offline)'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('connection_banner_offline')), findsOneWidget);

      // Verify text color is danger (red)
      final textWidget = tester.widget<Text>(find.text('Disconnected'));
      expect(textWidget.style?.color, CompozyColors.danger);

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('renders green badge via connectionStatusProvider override', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byKey(const Key('connection_banner_online')), findsOneWidget);
    });

    testWidgets('renders red banner via connectionStatusProvider override', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionBanner(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.byKey(const Key('connection_banner_offline')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders compact pill when online and offline', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ConnectionBanner.compact(isOnline: true),
                  ConnectionBanner.compact(isOnline: false),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('online'), findsOneWidget);
      expect(find.text('offline'), findsOneWidget);
      expect(find.byKey(const Key('connection_pill_online')), findsOneWidget);
      expect(find.byKey(const Key('connection_pill_offline')), findsOneWidget);
    });
  });
}
