import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:top_banner_example/banner/banner.dart';
import 'package:top_banner_example/main.dart';

const leafSpec = BannerSpec(message: 'leaf banner');
const sectionSpec = BannerSpec(message: 'section banner');
const winningLeafSpec = BannerSpec(message: 'winning leaf', priority: 10);
const outerSpec = BannerSpec(message: 'outer banner', priority: 99);
const deepShellSpec = BannerSpec(message: 'deep shell', priority: 5);
const dangerSpec = BannerSpec(message: 'danger banner', priority: 40);
const tabSpec = BannerSpec(message: 'tab banner');

Widget _body(String label) => Scaffold(body: Center(child: Text(label)));

/// ShellRoute asserts a non-empty child list; resolution never looks at it.
final _stub = [GoRoute(path: '/stub', builder: (c, s) => _body('stub'))];

/// Two nested shells, each adding visible chrome, so a marker on a leaf has to
/// travel up through both to reach the root.
List<RouteBase> _routes() => [
  ShellRoute(
    builder: (context, state, child) => Column(
      children: [
        const Text('outer chrome'),
        Expanded(child: child),
      ],
    ),
    routes: [
      GoRoute(path: '/', builder: (c, s) => _body('home')),
      BannerRoute(
        path: '/promo',
        banner: leafSpec,
        builder: (c, s) => _body('promo'),
      ),
      // Two banners from a single route.
      BannerRoute(
        path: '/double',
        banners: const [leafSpec, outerSpec],
        builder: (c, s) => _body('double'),
      ),
      BannerShellRoute(
        banner: sectionSpec,
        builder: (context, state, child) => Column(
          children: [
            const Text('inner chrome'),
            Expanded(child: child),
          ],
        ),
        routes: [
          GoRoute(path: '/beta', builder: (c, s) => _body('beta')),
          BannerRoute(
            path: '/beta/call',
            banner: winningLeafSpec,
            builder: (c, s) => _body('call'),
          ),
          // Shell 3: no marker, so it must be transparent to resolution.
          ShellRoute(
            builder: (context, state, child) => Column(
              children: [
                const Text('shell3 chrome'),
                Expanded(child: child),
              ],
            ),
            routes: [
              GoRoute(path: '/beta/tools', builder: (c, s) => _body('tools')),
              // Shell 4: marked again, four levels deep.
              BannerShellRoute(
                banner: deepShellSpec,
                builder: (context, state, child) => Column(
                  children: [
                    const Text('shell4 chrome'),
                    Expanded(child: child),
                  ],
                ),
                routes: [
                  GoRoute(
                    path: '/beta/tools/sandbox',
                    builder: (c, s) => _body('sandbox'),
                  ),
                  BannerRoute(
                    path: '/beta/tools/sandbox/danger',
                    banner: dangerSpec,
                    builder: (c, s) => _body('danger'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Column(
          children: [
            const Text('tabs chrome'),
            Expanded(child: shell),
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              BannerRoute(
                path: '/tabs/inbox',
                banner: tabSpec,
                builder: (c, s) => _body('inbox'),
                routes: [
                  GoRoute(path: 'detail', builder: (c, s) => _body('detail')),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tabs/profile',
                builder: (c, s) => _body('profile'),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/',
  List<RouteBase>? routes,
  int? maxVisible,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: routes ?? _routes(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          RootBanner(router: router, maxVisible: maxVisible, child: child!),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('marker resolution', () {
    BannerRoute leaf({BannerSpec? banner, List<BannerSpec>? banners}) =>
        BannerRoute(
          path: '/x',
          banner: banner,
          banners: banners ?? const [],
          builder: (c, s) => _body('x'),
        );

    test('no markers resolves to an empty stack', () {
      expect(RootBanner.resolve(const <RouteBase>[]), isEmpty);
    });

    test('markers along the chain stack, deepest first on a tie', () {
      final outer = BannerShellRoute(banner: sectionSpec, routes: _stub);
      // Chain order is outermost -> leaf.
      expect(RootBanner.resolve([outer, leaf(banner: leafSpec)]), [
        leafSpec,
        sectionSpec,
      ]);
    });

    test('higher priority sits on top regardless of depth', () {
      final outer = BannerShellRoute(banner: outerSpec, routes: _stub);
      expect(RootBanner.resolve([outer, leaf(banner: leafSpec)]), [
        outerSpec,
        leafSpec,
      ]);
    });

    test('one route can declare several banners', () {
      expect(
        RootBanner.resolve([
          leaf(banners: [leafSpec, sectionSpec]),
        ]),
        [leafSpec, sectionSpec],
      );
    });

    test('declaration order is kept within one marker on a tie', () {
      const a = BannerSpec(message: 'a');
      const b = BannerSpec(message: 'b');
      expect(
        RootBanner.resolve([
          leaf(banners: [b, a]),
        ]),
        [b, a],
      );
    });

    test('banner is prepended to banners when both are given', () {
      expect(
        RootBanner.resolve([
          leaf(banner: outerSpec, banners: [leafSpec]),
        ]),
        [outerSpec, leafSpec],
      );
    });

    test('a marker declaring nothing contributes nothing', () {
      final outer = BannerShellRoute(banner: sectionSpec, routes: _stub);
      expect(RootBanner.resolve([outer, leaf()]), [sectionSpec]);
    });

    test('maxVisible keeps the highest priority banners', () {
      final outer = BannerShellRoute(banner: outerSpec, routes: _stub);
      expect(
        RootBanner.resolve([outer, leaf(banner: leafSpec)], maxVisible: 1),
        [outerSpec],
      );
    });
  });

  group('root banner', () {
    testWidgets('no marker means no banner', (tester) async {
      await pumpApp(tester);
      expect(find.text('home'), findsOne);
      expect(find.text(leafSpec.message), findsNothing);
    });

    testWidgets('leaf marker shows the banner at the root', (tester) async {
      final router = await pumpApp(tester);
      router.go('/promo');
      await tester.pumpAndSettle();

      expect(find.text('promo'), findsOne);
      expect(find.text(leafSpec.message), findsOne);
    });

    testWidgets('banner renders above both shells and the AppBar', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta/call');
      await tester.pumpAndSettle();

      final banner = tester.getTopLeft(find.text(winningLeafSpec.message)).dy;
      final outerChrome = tester.getTopLeft(find.text('outer chrome')).dy;
      final innerChrome = tester.getTopLeft(find.text('inner chrome')).dy;

      expect(banner, lessThan(outerChrome));
      expect(outerChrome, lessThan(innerChrome));
    });

    testWidgets('marker on an inner shell covers its children', (tester) async {
      final router = await pumpApp(tester);
      router.go('/beta');
      await tester.pumpAndSettle();

      expect(find.text('inner chrome'), findsOne);
      expect(find.text(sectionSpec.message), findsOne);
    });

    testWidgets('leaf and section markers stack, leaf on top', (tester) async {
      final router = await pumpApp(tester);
      router.go('/beta/call');
      await tester.pumpAndSettle();

      expect(find.byType(BannerView), findsExactly(2));
      expect(
        tester.getTopLeft(find.text(winningLeafSpec.message)).dy,
        lessThan(tester.getTopLeft(find.text(sectionSpec.message)).dy),
      );
      // Both sit above the shell chrome they came from.
      expect(
        tester.getBottomLeft(find.text(sectionSpec.message)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('outer chrome')).dy),
      );
    });

    testWidgets('one route can show two banners', (tester) async {
      final router = await pumpApp(tester);
      router.go('/double');
      await tester.pumpAndSettle();

      expect(find.byType(BannerView), findsExactly(2));
      // outerSpec has priority 99, leafSpec 0, so order is by priority not list
      // order.
      expect(
        tester.getTopLeft(find.text(outerSpec.message)).dy,
        lessThan(tester.getTopLeft(find.text(leafSpec.message)).dy),
      );
    });

    testWidgets('maxVisible caps the stack, keeping the top banner', (
      tester,
    ) async {
      final router = await pumpApp(tester, maxVisible: 1);
      router.go('/beta/call');
      await tester.pumpAndSettle();

      expect(find.byType(BannerView), findsOne);
      expect(find.text(winningLeafSpec.message), findsOne);
      expect(find.text(sectionSpec.message), findsNothing);
    });

    testWidgets('stack shrinks back to one banner and then to none', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta/call');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsExactly(2));

      router.go('/beta');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('banner clears when leaving a marked route', (tester) async {
      final router = await pumpApp(tester);
      router.go('/promo');
      await tester.pumpAndSettle();
      expect(find.text(leafSpec.message), findsOne);

      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text(leafSpec.message), findsNothing);
    });

    testWidgets('deep link straight to a marked route shows the banner', (
      tester,
    ) async {
      // The old design hung here: notifyListeners fired during the initial
      // mount, which builds with schedulerPhase == idle.
      await pumpApp(tester, initialLocation: '/beta/call');
      expect(find.text(winningLeafSpec.message), findsOne);
    });

    testWidgets('settles: no repeating-frame loop', (tester) async {
      await pumpApp(tester, initialLocation: '/promo');
      // pumpAndSettle above already proves it; assert the binding is idle too.
      expect(find.text(leafSpec.message), findsOne);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('deeply nested shells', () {
    testWidgets('an unmarked shell in the middle is transparent', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta/tools');
      await tester.pumpAndSettle();

      // Shell 3 is on screen but declares nothing, so only shell 2's banner.
      expect(find.text('shell3 chrome'), findsOne);
      expect(find.byType(BannerView), findsOne);
      expect(find.text(sectionSpec.message), findsOne);
    });

    testWidgets('markers on shells 2 and 4 stack, deepest on top', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta/tools/sandbox');
      await tester.pumpAndSettle();

      expect(find.text('shell4 chrome'), findsOne);
      expect(find.byType(BannerView), findsExactly(2));
      // deepShellSpec (5) outranks sectionSpec (0).
      expect(
        tester.getTopLeft(find.text(deepShellSpec.message)).dy,
        lessThan(tester.getTopLeft(find.text(sectionSpec.message)).dy),
      );
    });

    testWidgets('three markers across four shell levels all show', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta/tools/sandbox/danger');
      await tester.pumpAndSettle();

      expect(find.byType(BannerView), findsExactly(3));

      // Ordered by priority: danger (40), deep shell (5), section (0).
      final danger = tester.getTopLeft(find.text(dangerSpec.message)).dy;
      final deep = tester.getTopLeft(find.text(deepShellSpec.message)).dy;
      final section = tester.getTopLeft(find.text(sectionSpec.message)).dy;
      expect(danger, lessThan(deep));
      expect(deep, lessThan(section));

      // The whole stack still sits above every shell's chrome.
      expect(
        section,
        lessThan(tester.getTopLeft(find.text('outer chrome')).dy),
      );
    });

    testWidgets('walking back up the chain drops one banner at a time', (
      tester,
    ) async {
      final router = await pumpApp(
        tester,
        initialLocation: '/beta/tools/sandbox/danger',
      );
      expect(find.byType(BannerView), findsExactly(3));

      router.go('/beta/tools/sandbox');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsExactly(2));

      router.go('/beta/tools');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      router.go('/plain');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('deep link four shells down resolves the whole chain', (
      tester,
    ) async {
      await pumpApp(tester, initialLocation: '/beta/tools/sandbox/danger');
      expect(find.byType(BannerView), findsExactly(3));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('StatefulShellRoute', () {
    testWidgets('a marker on a branch root route is found', (tester) async {
      final router = await pumpApp(tester);
      router.go('/tabs/inbox');
      await tester.pumpAndSettle();

      expect(find.text('tabs chrome'), findsOne);
      expect(find.text(tabSpec.message), findsOne);
    });

    testWidgets('it keeps applying to routes nested under the branch root', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/tabs/inbox/detail');
      await tester.pumpAndSettle();

      expect(find.text('detail'), findsOne);
      expect(find.text(tabSpec.message), findsOne);
    });

    testWidgets('switching to an unmarked branch clears the banner', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/tabs/inbox');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      router.go('/tabs/profile');
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsNothing);
    });
  });

  group('imperative navigation', () {
    testWidgets('push shows the banner, pop clears it', (tester) async {
      await pumpApp(tester);
      expect(find.text(leafSpec.message), findsNothing);

      final context = tester.element(find.text('home'));
      context.push('/promo');
      await tester.pumpAndSettle();
      expect(find.text(leafSpec.message), findsOne);

      context.pop();
      await tester.pumpAndSettle();
      expect(find.text(leafSpec.message), findsNothing);
    });

    testWidgets('push from a marked section resolves the pushed route', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      router.go('/beta');
      await tester.pumpAndSettle();
      expect(find.text(sectionSpec.message), findsOne);

      tester.element(find.text('beta')).push('/beta/call');
      await tester.pumpAndSettle();
      expect(find.text(winningLeafSpec.message), findsOne);
      expect(find.text(sectionSpec.message), findsOne);
    });
  });

  group('layout', () {
    testWidgets('banner consumes the status bar inset instead of doubling it', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 100);
      tester.view.viewPadding = const FakeViewPadding(top: 100);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      final topInset = 100 / tester.view.devicePixelRatio;
      final router = await pumpApp(tester);

      // No banner: the page keeps the full inset.
      final homeContext = tester.element(find.text('home'));
      expect(MediaQuery.paddingOf(homeContext).top, closeTo(topInset, 0.01));
      final screenHeight = MediaQuery.sizeOf(homeContext).height;

      router.go('/promo');
      await tester.pumpAndSettle();

      // The banner starts at y=0, painting up behind the status bar, and is
      // exactly inset + contentHeight tall.
      expect(tester.getTopLeft(find.byType(BannerView)).dy, 0);
      final bannerHeight = tester.getSize(find.byType(BannerView)).height;
      expect(bannerHeight, closeTo(topInset + 44, 0.01));

      // The page below no longer re-applies the inset (that was the jolt), and
      // its reported size shrank by exactly what the banner occupies.
      final promoContext = tester.element(find.text('promo'));
      expect(MediaQuery.paddingOf(promoContext).top, 0);
      expect(MediaQuery.viewPaddingOf(promoContext).top, 0);
      expect(
        MediaQuery.sizeOf(promoContext).height,
        closeTo(screenHeight - bannerHeight, 0.01),
      );
    });

    testWidgets('only the top banner of a stack carries the status bar inset', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 100);
      tester.view.viewPadding = const FakeViewPadding(top: 100);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      final topInset = 100 / tester.view.devicePixelRatio;
      final router = await pumpApp(tester);
      final screenHeight = MediaQuery.sizeOf(
        tester.element(find.text('home')),
      ).height;

      router.go('/double');
      await tester.pumpAndSettle();

      final boxes = find.byType(BannerView);
      expect(boxes, findsExactly(2));

      // Top banner: inset + content. Second: content only, stacked directly
      // beneath it.
      expect(tester.getTopLeft(boxes.first).dy, 0);
      expect(tester.getSize(boxes.first).height, closeTo(topInset + 44, 0.01));
      expect(tester.getSize(boxes.at(1)).height, closeTo(44, 0.01));
      expect(
        tester.getTopLeft(boxes.at(1)).dy,
        closeTo(tester.getBottomLeft(boxes.first).dy, 0.01),
      );

      // The page below has the whole stack consumed from its metrics exactly
      // once.
      final pageContext = tester.element(find.text('double'));
      expect(MediaQuery.paddingOf(pageContext).top, 0);
      expect(
        MediaQuery.sizeOf(pageContext).height,
        closeTo(screenHeight - (topInset + 88), 0.01),
      );
    });

    testWidgets(
      'shrinking MediaQuery.size keeps a full-height page in bounds',
      (tester) async {
        final probe = GlobalKey();
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (c, s) => _body('home')),
            BannerRoute(
              path: '/tall',
              banner: leafSpec,
              builder: (c, s) => SizedBox(
                key: probe,
                height: MediaQuery.sizeOf(c).height,
                child: const Text('tall'),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                RootBanner(router: router, child: child!),
          ),
        );
        await tester.pumpAndSettle();

        router.go('/tall');
        await tester.pumpAndSettle();

        // The old design left size untouched, overflowing by the banner height.
        expect(tester.takeException(), isNull);
        final screen =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(tester.getSize(find.byKey(probe)).height, lessThan(screen));
      },
    );

    testWidgets('the Navigator is not remounted when the banner appears', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      final before = tester.state(find.byType(Navigator).first);

      router.go('/promo');
      await tester.pumpAndSettle();

      // A changing Column children list would tear down the whole router.
      expect(tester.state(find.byType(Navigator).first), same(before));
    });
  });

  group('back navigation', () {
    testWidgets('no back arrow when there is nothing to pop', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);

      // Nav bar destinations use `go`, which replaces rather than pushes.
      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Beta home'), findsOne);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('back arrow appears after a push and returns', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Push the promo page'));
      await tester.pumpAndSettle();
      expect(find.text('Promo'), findsOne);
      expect(find.byType(BackButton), findsOne);
      expect(find.byType(BannerView), findsOne);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // 'Home' also labels a nav destination, so match the page's own text.
      expect(find.text('No marker on this route, so no banner.'), findsOne);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('back arrow walks out of four nested shells', (tester) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.science_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      // Descend: shell 3 (unmarked), shell 4, then the leaf.
      await tester.tap(find.text('Push into shell 3'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOne);
      expect(find.byType(BannerView), findsOne);

      await tester.tap(find.text('Push into shell 4'));
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsExactly(2));

      await tester.tap(find.text('Push the danger page'));
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsExactly(3));

      // Walk back out. Each pop is on a different inner Navigator, and one
      // button in shell 1 has to reach all of them.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Sandbox'), findsOne);
      expect(find.byType(BannerView), findsExactly(2));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Tools'), findsOne);
      expect(find.byType(BannerView), findsOne);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Beta home'), findsOne);
      expect(find.byType(BannerView), findsOne);
      // Back at a `go` destination, so the arrow is gone again.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('back arrow pops within a stateful shell branch', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tab_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Inbox tab'), findsOne);
      expect(find.byType(BackButton), findsNothing);

      tester.element(find.text('Inbox tab')).push('/promo');
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOne);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Inbox tab'), findsOne);
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('example app', () {
    testWidgets('main.dart wiring resolves markers at every depth', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Shell 1's AppBar title is present on every route, so it is a stable
      // navigation context for the whole walk.
      Future<void> go(String location) async {
        tester.element(find.text('Shell 1 — app chrome')).go(location);
        await tester.pumpAndSettle();
      }

      double topOf(BannerSpec spec) =>
          tester.getTopLeft(find.text(spec.message)).dy;

      expect(find.byType(BannerView), findsNothing);

      await go('/promo');
      expect(find.byType(BannerView), findsOne);

      // Two banners from one route, ordered by priority not list order.
      await go('/double');
      expect(find.byType(BannerView), findsExactly(2));
      expect(topOf(Banners.offline), lessThan(topOf(Banners.promo)));

      // Shell 2's marker alone.
      await go('/beta');
      expect(find.byType(BannerView), findsOne);
      expect(find.text(Banners.betaSection.message), findsOne);

      // Leaf stacked above shell 2.
      await go('/beta/call');
      expect(find.byType(BannerView), findsExactly(2));
      expect(topOf(Banners.call), lessThan(topOf(Banners.betaSection)));

      // Shell 3 declares nothing, so descending into it changes nothing.
      await go('/beta/tools');
      expect(find.byType(BannerView), findsOne);
      expect(find.text(Banners.betaSection.message), findsOne);

      // Shell 4 adds one, four levels deep.
      await go('/beta/tools/sandbox');
      expect(find.byType(BannerView), findsExactly(2));
      expect(topOf(Banners.sandbox), lessThan(topOf(Banners.betaSection)));

      // Leaf + shell 4 + shell 2.
      await go('/beta/tools/sandbox/danger');
      expect(find.byType(BannerView), findsExactly(3));
      expect(topOf(Banners.danger), lessThan(topOf(Banners.sandbox)));
      expect(topOf(Banners.sandbox), lessThan(topOf(Banners.betaSection)));

      // StatefulShellRoute: marker on the marked branch's root route only.
      await go('/tabs/inbox');
      expect(find.byType(BannerView), findsOne);
      expect(find.text(Banners.inbox.message), findsOne);

      await go('/tabs/profile');
      expect(find.byType(BannerView), findsNothing);
    });
  });
}
