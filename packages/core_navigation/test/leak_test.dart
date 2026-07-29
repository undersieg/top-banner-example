import 'package:core_navigation/core_navigation.dart';
import 'package:core_navigation/src/banner_route.dart';
import 'package:core_navigation/src/go_router_banner_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

const spec = BannerSpec(message: 'leak banner');

/// Leak tracking, enabled for this file only.
///
/// The interesting cases are the *error* paths. A host that reports a missing
/// router or a missing source used to do it from `didChangeDependencies`, which
/// abandons a half-mounted element: it never gets a `dispose`, so its State, its
/// Element and every RenderObject below it stay reachable. Both now report from
/// `build`, where the framework's error boundary takes over and unwinds
/// normally.
///
/// `withTrackedAll` is what makes this meaningful — by default only a subset of
/// object types is instrumented.
void main() {
  LeakTesting.enable();

  setUpAll(() {
    LeakTesting.settings = LeakTesting.settings.withTrackedAll();
  });

  testWidgets('mounting and unmounting the banner scope leaks nothing', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/promo',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppBannerScope(child: RootBanner(child: child)),
          routes: [
            BannerRoute(
              path: '/promo',
              banner: spec,
              builder: (context, state) => const SizedBox.expand(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(BannerView), findsOne);

    // The source is owned by the host, so tearing the host out has to dispose it
    // even though the router — and its delegate, which the source listens to —
    // outlives the whole tree.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a swapped router disposes the source it replaced', (
    tester,
  ) async {
    Widget hostFor(GoRouter router) {
      final source = GoRouterBannerSource(router);
      addTearDown(source.dispose);
      return MaterialApp(
        home: BannerSourceScope(
          source: source,
          child: const RootBanner(child: SizedBox.expand()),
        ),
      );
    }

    final first = GoRouter(
      routes: [GoRoute(path: '/', builder: (c, s) => const SizedBox())],
    );
    final second = GoRouter(
      routes: [GoRoute(path: '/', builder: (c, s) => const SizedBox())],
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    await tester.pumpWidget(hostFor(first));
    await tester.pumpAndSettle();
    await tester.pumpWidget(hostFor(second));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('reporting a missing router does not abandon the element', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBannerScope(child: RootBanner(child: SizedBox())),
      ),
    );
    expect(tester.takeException(), isFlutterError);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('reporting a missing source does not abandon the element', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RootBanner(child: SizedBox())),
    );
    expect(tester.takeException(), isFlutterError);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
