import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/agents/domain/models/agent_presence.dart';
import 'package:compozy_app/features/agents/presentation/widgets/agent_avatar.dart';

void main() {
  group('AgentAvatar color derivation and contrast', () {
    Widget buildAvatarWrapper({
      required Widget child,
      ThemeMode themeMode = ThemeMode.dark,
    }) {
      return MaterialApp(
        themeMode: themeMode,
        theme: CompozyTheme.lightTheme,
        darkTheme: CompozyTheme.darkTheme,
        home: Scaffold(body: Center(child: child)),
      );
    }

    testWidgets('agents with default #7c5cff color produce distinct seed-derived hues', (tester) async {
      final seeds = ['dispatcher', 'fixer', 'audit_planner', 'council'];
      final containers = <Container>[];

      for (final seed in seeds) {
        await tester.pumpWidget(
          buildAvatarWrapper(
            child: AgentAvatar(
              appearance: AgentAppearance(
                avatar: 'generated',
                colorHex: '#7c5cff',
                seed: seed,
              ),
              label: seed,
              name: seed,
            ),
          ),
        );

        final containerFinder = find.byType(Container).first;
        final container = tester.widget<Container>(containerFinder);
        containers.add(container);
      }

      // Extract gradients from each avatar
      final gradients = containers.map((c) => (c.decoration as BoxDecoration).gradient as LinearGradient).toList();

      // Ensure every agent has a distinct starting color
      final colors = gradients.map((g) => g.colors.first).toSet();
      expect(colors.length, equals(4), reason: 'All 4 agents must have distinct colors');
    });

    testWidgets('custom non-default color is preserved', (tester) async {
      await tester.pumpWidget(
        buildAvatarWrapper(
          child: const AgentAvatar(
            appearance: AgentAppearance(
              avatar: 'generated',
              colorHex: '#E8572A', // Custom accent color
              seed: 'custom_agent',
            ),
            label: 'Custom',
            name: 'custom_agent',
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final gradient = (container.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, equals(const Color(0xFFE8572A)));
    });

    testWidgets('adapts lightness between dark and light themes for contrast', (tester) async {
      const appearance = AgentAppearance(
        avatar: 'generated',
        colorHex: '#7c5cff',
        seed: 'dispatcher',
      );

      // Dark theme pump
      await tester.pumpWidget(
        buildAvatarWrapper(
          themeMode: ThemeMode.dark,
          child: const AgentAvatar(
            appearance: appearance,
            label: 'Dispatcher',
            name: 'dispatcher',
          ),
        ),
      );
      final darkContainer = tester.widget<Container>(find.byType(Container).first);
      final darkGrad = (darkContainer.decoration as BoxDecoration).gradient as LinearGradient;
      final darkBaseColor = darkGrad.colors.first;

      // Light theme pump
      await tester.pumpWidget(
        buildAvatarWrapper(
          themeMode: ThemeMode.light,
          child: const AgentAvatar(
            key: ValueKey('light'),
            appearance: appearance,
            label: 'Dispatcher',
            name: 'dispatcher',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lightContainer = tester.widget<Container>(find.descendant(
        of: find.byKey(const ValueKey('light')),
        matching: find.byType(Container),
      ).first);
      final lightGrad = (lightContainer.decoration as BoxDecoration).gradient as LinearGradient;
      final lightBaseColor = lightGrad.colors.first;
      // In light theme, the base color should have higher lightness than in dark theme
      final darkHsl = HSLColor.fromColor(darkBaseColor);
      final lightHsl = HSLColor.fromColor(lightBaseColor);
      expect(lightHsl.lightness, greaterThan(darkHsl.lightness));
      expect(lightHsl.hue, closeTo(darkHsl.hue, 0.5));
    });

    testWidgets('renders initials and presence status dot', (tester) async {
      await tester.pumpWidget(
        buildAvatarWrapper(
          child: const AgentAvatar(
            appearance: AgentAppearance(
              avatar: 'generated',
              colorHex: '#7c5cff',
              seed: 'audit_planner',
            ),
            label: 'Audit Planner',
            name: 'audit_planner',
            status: AgentPresenceStatus.working,
          ),
        ),
      );

      expect(find.text('AP'), findsOneWidget);
      expect(find.byKey(const Key('agent_avatar_status_dot_working')), findsOneWidget);
    });

    testWidgets('guarantees WCAG AA contrast >= 4.5:1 across 24 distinct seeds in both dark and light themes', (tester) async {
      double calculateContrastRatio(Color c1, Color c2) {
        final l1 = c1.computeLuminance();
        final l2 = c2.computeLuminance();
        final lighter = math.max(l1, l2);
        final darker = math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
      }

      final seeds = [
        'dispatcher',
        'fixer',
        'audit_planner',
        'council',
        'explorer',
        'oracle',
        'designer',
        'architect',
        'reviewer',
        'tester',
        'builder',
        'coordinator',
        'worker_1',
        'worker_2',
        'monitor',
        'sentinel',
        'guardian',
        'pilot',
        'navigator',
        'scribe',
        'analyst',
        'strategist',
        'operator',
        'specialist',
      ];

      expect(seeds.length, greaterThanOrEqualTo(24));

      for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
        for (final seed in seeds) {
          await tester.pumpWidget(
            buildAvatarWrapper(
              themeMode: themeMode,
              child: AgentAvatar(
                key: ValueKey('$themeMode-$seed'),
                appearance: AgentAppearance(
                  avatar: 'generated',
                  colorHex: '#7c5cff',
                  seed: seed,
                ),
                label: seed,
                name: seed,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final container = tester.widget<Container>(find.byType(Container).first);
          final gradient = (container.decoration as BoxDecoration).gradient as LinearGradient;
          final baseColor = gradient.colors.first;
          final endColor = gradient.colors.last;

          final text = tester.widget<Text>(find.byType(Text).first);
          final glyphColor = text.style!.color!;

          final ratioBase = calculateContrastRatio(baseColor, glyphColor);
          final ratioEnd = calculateContrastRatio(endColor, glyphColor);

          expect(
            ratioBase,
            greaterThanOrEqualTo(4.5),
            reason: 'Seed "$seed" in $themeMode must meet WCAG AA (>= 4.5) against baseColor ($ratioBase)',
          );
          expect(
            ratioEnd,
            greaterThanOrEqualTo(4.5),
            reason: 'Seed "$seed" in $themeMode must meet WCAG AA (>= 4.5) against gradient endColor ($ratioEnd)',
          );
        }
      }
    });
  });
}
