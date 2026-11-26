import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:compozy_app/core/app_info.dart';

void main() {
  group('App version single source of truth', () {
    test('kAppVersion matches pubspec.yaml SemVer without build metadata', () {
      final pubspecFile = File('pubspec.yaml');
      expect(
        pubspecFile.existsSync(),
        isTrue,
        reason: 'pubspec.yaml must exist at the project root',
      );

      final content = pubspecFile.readAsStringSync();
      final match = RegExp(
        r'^version:\s*([^\s#]+)',
        multiLine: true,
      ).firstMatch(content);

      expect(
        match,
        isNotNull,
        reason: 'pubspec.yaml must declare a version: field',
      );

      final rawVersion = match!.group(1)!;
      final semver = rawVersion.split('+').first;

      expect(
        semver,
        matches(RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$')),
        reason: 'pubspec.yaml version must follow Semantic Versioning 2.0.0',
      );
      expect(
        kAppVersion,
        equals(semver),
        reason:
            'kAppVersion in lib/core/app_info.dart must match pubspec.yaml version ($semver)',
      );
      expect(kAppStage.trim(), isNotEmpty);
    });
  });
}
