import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Leak tracking for the whole suite.
///
/// It has to be installed here rather than from a test's `main`: instrumentation
/// wraps object *creation*, so enabling it once the binding is up finds nothing
/// and passes vacuously.
///
/// `withTrackedAll` widens tracking past the default subset of types, which is
/// what makes an undisposed listener or an abandoned element visible.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll();
  await testMain();
}
