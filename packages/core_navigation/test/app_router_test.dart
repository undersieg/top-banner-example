import 'package:core_navigation/core_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const promo = BannerSpec(message: 'promo banner', priority: 10);
const section = BannerSpec(message: 'section banner');
const tab = BannerSpec(message: 'tab banner');

Widget _body(String label) => Scaffold(body: Center(child: Text(label)));

/// The app-facing surface: route model, router, navigator, banner scope.
///
/// Deliberately imports the barrel and nothing else. If any of this needed a
/// go_router type to express, it would show up here as an import — which is the
/// property that makes the router replaceable.
void main() {
  /// The demo's shape in miniature: outer shell, a leaf, a nested shell with a
  /// leaf of its own, and tabs.
  List<AppRoute> routes() => [
    AppShellRoute(
      builder: (context, child) => AppBannerScope(
        child: RootBanner(child: _Chrome(child: child)),
      ),
      children: [
        AppPageRoute(path: '/', builder: (context) => _body('home')),
        AppPageRoute(
          path: '/promo',
          banner: promo,
          builder: (context) => _body('promo'),
        ),
        AppShellRoute(
          banner: section,
          builder: (context, child) => child,
          children: [
            AppPageRoute(
              path: '/beta',
              builder: (context) => _body('beta'),
              children: [
                AppPageRoute(path: 'deep', builder: (context) => _body('deep')),
              ],
            ),
          ],
        ),
        AppTabsRoute(
          builder: (context, tabs) => _Tabs(tabs: tabs),
          branches: [
            AppTabBranch(
              routes: [
                AppPageRoute(
                  path: '/tabs/inbox',
                  banner: tab,
                  builder: (context) => _body('inbox'),
                ),
              ],
            ),
            AppTabBranch(
              routes: [
                AppPageRoute(
                  path: '/tabs/profile',
                  builder: (context) => _body('profile'),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  Future<AppRouter> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    final router = AppRouter(
      routes: routes(),
      initialLocation: initialLocation,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
    await tester.pumpAndSettle();
    return router;
  }

  /// Navigates from a page's own context, the way app code does.
  AppNavigator navigatorAt(WidgetTester tester, String text) =>
      AppNavigator.of(tester.element(find.text(text)));

  group('route model', () {
    testWidgets('a page route with no banner shows none', (tester) async {
      await pumpApp(tester);
      expect(find.text('home'), findsOne);
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('a banner on a page route reaches the root', (tester) async {
      await pumpApp(tester, initialLocation: '/promo');
      expect(find.text(promo.message), findsOne);
      // Above the shell's chrome, which is the point of hosting it out here.
      expect(
        tester.getTopLeft(find.text(promo.message)).dy,
        lessThan(tester.getTopLeft(find.text('chrome')).dy),
      );
    });

    testWidgets('a banner on a shell route covers what is nested in it', (
      tester,
    ) async {
      await pumpApp(tester, initialLocation: '/beta');
      expect(find.text(section.message), findsOne);

      // Including a child route two levels down.
      navigatorAt(tester, 'beta').push('/beta/deep');
      await tester.pumpAndSettle();
      expect(find.text('deep'), findsOne);
      expect(find.text(section.message), findsOne);
    });

    testWidgets('a banner on a tab branch root is found', (tester) async {
      await pumpApp(tester, initialLocation: '/tabs/inbox');
      expect(find.text(tab.message), findsOne);
    });

    testWidgets('switching tabs re-resolves the stack', (tester) async {
      await pumpApp(tester, initialLocation: '/tabs/inbox');
      expect(find.byType(BannerView), findsOne);

      await tester.tap(find.text('tab 1'));
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsOne);
      expect(find.byType(BannerView), findsNothing);
    });
  });

  group('AppNavigator', () {
    testWidgets('go replaces, so there is nothing to pop', (tester) async {
      await pumpApp(tester);
      final navigator = navigatorAt(tester, 'home');
      expect(navigator.canPop, isFalse);

      navigator.go('/promo');
      await tester.pumpAndSettle();
      expect(find.text('promo'), findsOne);
      expect(navigatorAt(tester, 'promo').canPop, isFalse);
    });

    testWidgets('push and pop, with the banner following both ways', (
      tester,
    ) async {
      await pumpApp(tester);
      navigatorAt(tester, 'home').push('/promo');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      final navigator = navigatorAt(tester, 'promo');
      expect(navigator.canPop, isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOne);
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('locationOf tracks navigation; of() does not rebuild', (
      tester,
    ) async {
      await pumpApp(tester);
      // _Chrome reads locationOf, so it has to follow a `go`.
      expect(find.text('at /'), findsOne);

      navigatorAt(tester, 'home').go('/promo');
      await tester.pumpAndSettle();
      expect(find.text('at /promo'), findsOne);
    });

    testWidgets('changes notifies after a navigation', (tester) async {
      await pumpApp(tester);
      var notifications = 0;
      final navigator = navigatorAt(tester, 'home');
      void listener() => notifications++;
      navigator.changes.addListener(listener);
      addTearDown(() => navigator.changes.removeListener(listener));

      navigator.push('/promo');
      await tester.pumpAndSettle();
      expect(notifications, greaterThan(0));
    });

    testWidgets('two navigators for the same router compare equal', (
      tester,
    ) async {
      // The demo's shell relies on this to avoid re-subscribing every time its
      // dependencies change.
      await pumpApp(tester);
      expect(navigatorAt(tester, 'home'), navigatorAt(tester, 'chrome'));
    });

    testWidgets('maybeOf is null above the Router', (tester) async {
      late AppNavigator? found;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              found = AppNavigator.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, isNull);
    });
  });

  group('AppCanPopBuilder', () {
    /// An outer shell holding the builder, an inner shell below it, and pages in
    /// both. The interesting pushes happen on the *inner* Navigator, which the
    /// outer shell cannot see by rebuilding.
    var builds = 0;
    var lastCanPop = false;

    Future<void> pumpNested(WidgetTester tester) async {
      builds = 0;
      lastCanPop = false;
      final router = AppRouter(
        routes: [
          AppShellRoute(
            builder: (context, child) => AppCanPopBuilder(
              builder: (context, canPop) {
                builds++;
                lastCanPop = canPop;
                return Column(
                  children: [
                    Text(canPop ? 'can pop' : 'cannot pop'),
                    Expanded(child: child),
                  ],
                );
              },
            ),
            children: [
              AppPageRoute(path: '/', builder: (context) => _body('home')),
              AppShellRoute(
                builder: (context, child) => child,
                children: [
                  AppPageRoute(
                    path: '/inner',
                    builder: (context) => _body('inner'),
                    children: [
                      AppPageRoute(
                        path: 'deep',
                        builder: (context) => _body('deep'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
    }

    testWidgets('nothing to pop', (tester) async {
      await pumpNested(tester);
      expect(find.text('cannot pop'), findsOne);
    });

    testWidgets('a push on an inner Navigator is seen', (tester) async {
      // The whole reason this widget exists: the outer shell's own route does not
      // change here, so nothing rebuilds it, and the inner NavigatorState only
      // takes on the new page list later in the same build pass.
      await pumpNested(tester);
      navigatorAt(tester, 'home').push('/inner');
      await tester.pumpAndSettle();
      expect(find.text('can pop'), findsOne);

      navigatorAt(tester, 'inner').push('/inner/deep');
      await tester.pumpAndSettle();
      expect(find.text('can pop'), findsOne);
    });

    testWidgets('popping back to the root reports nothing to pop again', (
      tester,
    ) async {
      await pumpNested(tester);
      navigatorAt(tester, 'home').push('/inner');
      await tester.pumpAndSettle();

      navigatorAt(tester, 'inner').pop();
      await tester.pumpAndSettle();
      expect(find.text('cannot pop'), findsOne);
    });

    testWidgets('a const builder still tracks navigation', (tester) async {
      // The reason this widget subscribes instead of scheduling its sample from
      // build. A shell's builder does re-run on every navigation, so sampling
      // from build works — until the widget handed down is *identical* rather
      // than merely equal, as a const one is. The element short-circuits, no
      // build happens, no sample is taken, and the back arrow silently never
      // appears. Measured: without the subscription this reports canPop=false
      // while canPop is true.
      final router = AppRouter(
        routes: [
          AppShellRoute(
            builder: (context, child) => Column(
              children: [
                // Identical instance on every rebuild of this builder.
                const AppCanPopBuilder(builder: _popLabel),
                Expanded(child: child),
              ],
            ),
            children: [
              AppPageRoute(path: '/', builder: (context) => _body('home')),
              AppPageRoute(path: '/next', builder: (context) => _body('next')),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();
      expect(find.text('cannot pop'), findsOne);

      navigatorAt(tester, 'home').push('/next');
      await tester.pumpAndSettle();
      expect(find.text('can pop'), findsOne);

      navigatorAt(tester, 'next').pop();
      await tester.pumpAndSettle();
      expect(find.text('cannot pop'), findsOne);
    });

    testWidgets('rebuilds only when the answer changes', (tester) async {
      await pumpNested(tester);
      final settled = builds;

      // A `go` that changes nothing about poppability.
      navigatorAt(tester, 'home').go('/');
      await tester.pumpAndSettle();
      expect(builds, settled, reason: 'the answer did not change');

      navigatorAt(tester, 'home').push('/inner');
      await tester.pumpAndSettle();
      expect(builds, greaterThan(settled));
      expect(lastCanPop, isTrue);
    });
  });

  group('AppBannerScope', () {
    testWidgets('mounted above the Router with an explicit router', (
      tester,
    ) async {
      // MaterialApp.router's builder sits above the Router, so nothing is in
      // scope to look up — the one case where the router is passed by hand.
      // Routes without a scope of their own, since exactly one host may be
      // mounted per tree.
      final router = AppRouter(
        routes: [
          AppPageRoute(
            path: '/promo',
            banner: promo,
            builder: (context) => _body('promo'),
          ),
        ],
        initialLocation: '/promo',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router.config,
          builder: (context, child) => AppBannerScope(
            router: router,
            child: RootBanner(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(promo.message), findsOne);
      expect(find.text('promo'), findsOne);
    });

    testWidgets('a shell that declares nothing adds no group to the chain', (
      tester,
    ) async {
      // Every AppShellRoute used to become a marker carrying an empty list, so a
      // policy saw one group per level of nesting whether or not that level had
      // an opinion — and "depth" counted shells that did not.
      final groups = <int>[];
      final router = AppRouter(
        routes: [
          AppShellRoute(
            builder: (context, child) => AppBannerScope(
              policy: (chain) {
                groups.add(chain.length);
                return BannerStack.order(chain);
              },
              child: RootBanner(child: child),
            ),
            children: [
              AppShellRoute(
                builder: (context, child) => child,
                children: [
                  AppPageRoute(
                    path: '/deep',
                    banner: promo,
                    builder: (context) => _body('deep'),
                  ),
                ],
              ),
            ],
          ),
        ],
        initialLocation: '/deep',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();

      expect(find.text(promo.message), findsOne);
      expect(
        groups,
        everyElement(1),
        reason: 'only the page declared anything',
      );
    });

    testWidgets('a custom policy replaces the ordering', (tester) async {
      final groupCounts = <int>[];
      List<BannerSpec> outermostFirst(Iterable<List<BannerSpec>> groups) {
        groupCounts.add(groups.length);
        return groups.expand((group) => group).toList();
      }

      final router = AppRouter(
        routes: [
          AppShellRoute(
            builder: (context, child) => AppBannerScope(
              policy: outermostFirst,
              child: RootBanner(child: child),
            ),
            children: [
              AppShellRoute(
                banner: section,
                builder: (context, child) => child,
                children: [
                  AppPageRoute(
                    path: '/deep',
                    banner: promo,
                    builder: (context) => _body('deep'),
                  ),
                ],
              ),
            ],
          ),
        ],
        initialLocation: '/deep',
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router.config));
      await tester.pumpAndSettle();

      // Default order would put promo (priority 10) on top.
      expect(
        tester.getTopLeft(find.text(section.message)).dy,
        lessThan(tester.getTopLeft(find.text(promo.message)).dy),
      );
      expect(groupCounts, everyElement(2));
    });
  });
}

class _Chrome extends StatelessWidget {
  const _Chrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('chrome'),
      Text('at ${AppNavigator.locationOf(context)}'),
      Expanded(child: child),
    ],
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs});

  final AppTabs tabs;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (var i = 0; i < 2; i++)
            TextButton(
              onPressed: () => tabs.goToBranch(i),
              child: Text('tab $i'),
            ),
        ],
      ),
      Text('showing ${tabs.currentIndex}'),
      Expanded(child: tabs.view),
    ],
  );
}

/// Top-level, so `const AppCanPopBuilder(builder: _popLabel)` is possible — which
/// is the point of the test that uses it.
Widget _popLabel(BuildContext context, bool canPop) =>
    Text(canPop ? 'can pop' : 'cannot pop');
