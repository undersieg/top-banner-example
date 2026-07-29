import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// This package renders banners and knows nothing about routing. That is now
/// enforced by pub — `pubspec.yaml` does not list go_router, so importing it here
/// does not resolve — which makes these tests a guard on the *pubspec* rather
/// than on the imports.
///
/// Worth keeping anyway: the failure mode is somebody adding the dependency to
/// fix one import, which compiles fine and quietly undoes the split.
void main() {
  test('the package depends on Flutter and nothing else', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec
        .split(RegExp(r'^dev_dependencies:', multiLine: true))
        .first
        .split(RegExp(r'^dependencies:', multiLine: true))
        .last
        .split('\n')
        // Top-level keys of the dependencies map, at two spaces of indent.
        .map((line) => RegExp(r'^  (\w+):').firstMatch(line)?.group(1))
        .whereType<String>();

    expect(
      dependencies,
      ['flutter'],
      reason:
          'A routing library — or anything else — belongs in an adapter '
          'package. See packages/core_navigation, which depends on this one and '
          'on go_router, and publishes a BannerSource (a plain ValueListenable) '
          'for RootBanner to read.',
    );
  });

  test('the implementation is private to the package', () {
    // Everything at the root of lib/ is a barrel. A consumer can only reach what
    // a barrel `show`s, which is what makes those clauses mean something.
    final public = Directory('lib')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toList();
    expect(public, ['banners.dart']);
  });

  test('nothing in lib reaches outside the package', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      for (final line in file.readAsLinesSync().map((line) => line.trim())) {
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        final uri = RegExp("""['"]([^'"]+)['"]""").firstMatch(line)?.group(1);
        if (uri == null) continue;
        final allowed =
            uri.startsWith('dart:') ||
            uri.startsWith('package:flutter/') ||
            (!uri.startsWith('package:') && !uri.startsWith('../'));
        if (!allowed) offenders.add('${file.path}: $line');
      }
    }
    expect(offenders, isEmpty);
  });
}
