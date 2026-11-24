import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';

void main() {
  group('CompozyTheme SystemUiOverlayStyle (status bar)', () {
    test('darkTheme declares light icons on transparent status bar', () {
      final style = CompozyTheme.darkTheme.appBarTheme.systemOverlayStyle;
      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
      expect(style.systemStatusBarContrastEnforced, isFalse);
    });

    test('lightTheme declares dark icons on transparent status bar', () {
      final style = CompozyTheme.lightTheme.appBarTheme.systemOverlayStyle;
      expect(style, isNotNull);
      expect(style!.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
      expect(style.systemStatusBarContrastEnforced, isFalse);
    });
  });
}
