import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app describes its routes and navigates through core_navigation's own
/// types, so it does not depend on a routing library — and cannot name one,
/// because the dependency is not there to resolve.
///
/// That is already enforced by the compiler. What is not, and what this guards,
/// is somebody adding the dependency back to fix a single import: it would
/// resolve, compile, and quietly undo the point of the layer.
void main() {
  test('the app does not depend on a routing library', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec
        .split(RegExp(r'^dev_dependencies:', multiLine: true))
        .first
        .split(RegExp(r'^dependencies:', multiLine: true))
        .last
        .split('\n')
        .map((line) => RegExp(r'^  (\w+):').firstMatch(line)?.group(1))
        .whereType<String>();

    expect(
      dependencies,
      isNot(contains('go_router')),
      reason:
          'Routing belongs behind core_navigation: describe routes with '
          'AppPageRoute / AppShellRoute / AppTabsRoute and navigate through '
          'AppNavigator. If something is missing from that surface, add it '
          'there rather than reaching past it.',
    );
  });

  test('no app source names a routing library', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        if (line.contains('go_router')) offenders.add('${file.path}: $line');
      }
    }
    expect(offenders, isEmpty);
  });
}
