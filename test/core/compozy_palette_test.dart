import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';

void main() {
  group('CompozyPalette', () {
    test('dark and light palettes define complete, distinct token sets', () {
      const dark = CompozyPalette.dark;
      const light = CompozyPalette.light;

      // Surface contrast
      expect(dark.canvas, equals(const Color(0xFF0A0A0A)));
      expect(light.canvas, equals(const Color(0xFFFFFFFF)));

      expect(dark.desk, equals(const Color(0xFF101010)));
      expect(light.desk, equals(const Color(0xFFF4F4F5)));

      expect(dark.card, equals(const Color(0xFF161616)));
      expect(light.card, equals(const Color(0xFFFFFFFF)));

      // Inverted monochrome actions
      expect(dark.primary, equals(const Color(0xFFF5F5F5)));
      expect(dark.primaryInk, equals(const Color(0xFF0A0A0A)));

      expect(light.primary, equals(const Color(0xFF0A0A0A)));
      expect(light.primaryInk, equals(const Color(0xFFFFFFFF)));

      // Lines
      expect(dark.line, equals(const Color(0xFF262626)));
      expect(light.line, equals(const Color(0xFFE4E4E7)));

      // Foregrounds
      expect(dark.fgStrong, equals(const Color(0xFFFFFFFF)));
      expect(light.fgStrong, equals(const Color(0xFF0A0A0A)));

      // Semantics
      expect(dark.accent, equals(const Color(0xFFE8572A)));
      expect(light.accent, equals(const Color(0xFFE8572A)));
      expect(dark.success, equals(const Color(0xFF34D399)));
      expect(light.success, equals(const Color(0xFF059669)));
    });

    test('lerp correctly blends colors between dark and light', () {
      const dark = CompozyPalette.dark;
      const light = CompozyPalette.light;

      final blended = dark.lerp(light, 0.5);
      expect(blended.canvas, equals(Color.lerp(dark.canvas, light.canvas, 0.5)));
      expect(blended.primary, equals(Color.lerp(dark.primary, light.primary, 0.5)));

      // lerp with non-palette returns this
      final fallback = dark.lerp(null, 0.5);
      expect(fallback, equals(dark));
    });

    test('copyWith creates a new instance with overridden fields', () {
      const original = CompozyPalette.dark;
      final modified = original.copyWith(
        canvas: const Color(0xFF000000),
        primary: const Color(0xFF123456),
      );

      expect(modified.canvas, equals(const Color(0xFF000000)));
      expect(modified.primary, equals(const Color(0xFF123456)));
      expect(modified.desk, equals(original.desk));
    });

    testWidgets('context.palette falls back to dark when extension is absent', (tester) async {
      late CompozyPalette resolvedPalette;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(), // No CompozyPalette extension
          home: Builder(
            builder: (context) {
              resolvedPalette = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedPalette, equals(CompozyPalette.dark));
    });

    testWidgets('context.palette resolves light tokens in lightTheme', (tester) async {
      late CompozyPalette resolvedPaletteLight;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.lightTheme,
          home: Builder(
            builder: (context) {
              resolvedPaletteLight = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedPaletteLight.canvas, equals(CompozyPalette.light.canvas));
      expect(resolvedPaletteLight.primary, equals(CompozyPalette.light.primary));
    });

    testWidgets('context.palette resolves dark tokens in darkTheme', (tester) async {
      late CompozyPalette resolvedPaletteDark;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Builder(
            builder: (context) {
              resolvedPaletteDark = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedPaletteDark.canvas, equals(CompozyPalette.dark.canvas));
      expect(resolvedPaletteDark.primary, equals(CompozyPalette.dark.primary));
    });
  });
}
