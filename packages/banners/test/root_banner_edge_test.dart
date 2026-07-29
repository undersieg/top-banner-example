import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:banners/banners.dart';

const spec = BannerSpec(message: 'edge banner');
const other = BannerSpec(message: 'other banner', priority: 5);
const third = BannerSpec(message: 'third banner', priority: 1);

Widget host(BannerSource source, {RootBannerStyle? style}) => MaterialApp(
  home: RootBanner(
    source: source,
    style: style ?? const RootBannerStyle(),
    child: const SizedBox.expand(),
  ),
);

/// Reports what the app below the strip is told about itself, and how often.
class _Probe extends StatelessWidget {
  const _Probe({this.onBuild, this.onSize});

  final VoidCallback? onBuild;
  final ValueChanged<Size>? onSize;

  @override
  Widget build(BuildContext context) {
    // Read unconditionally: the dependency is what makes a rebuild count mean
    // anything.
    final size = MediaQuery.sizeOf(context);
    onBuild?.call();
    onSize?.call(size);
    return const SizedBox.expand();
  }
}

/// Regressions found by review. Each of these either crashed, leaked, or broke
/// visually before the corresponding fix.
void main() {
  group('collapse lifecycle', () {
    testWidgets('a zero-duration collapse does not crash or retain', (
      tester,
    ) async {
      // onEnd fires synchronously from inside build for a zero-length
      // transition; setState there tripped assert(!_dirty) in framework.dart.
      final source = ValueNotifier<List<BannerSpec>>([spec]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        host(source, style: const RootBannerStyle(duration: Duration.zero)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      source.value = const [];
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BannerView), findsNothing);
    });

    testWidgets('swapping to an empty source does not crash or retain', (
      tester,
    ) async {
      // Same crash by another route: didUpdateWidget syncs with animate: false,
      // which is a zero-length transition. Reachable whenever an app rebuilds
      // its router (auth change, hot reload).
      final a = ValueNotifier<List<BannerSpec>>([spec]);
      final b = ValueNotifier<List<BannerSpec>>(const []);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await tester.pumpWidget(host(a));
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      await tester.pumpWidget(host(b));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BannerView), findsNothing);
    });

    test('degenerate contentHeight is rejected at construction', () {
      // 0 rendered invisible banners that were never released; negative values
      // threw ArgumentError out of clamp() deep inside build.
      for (final bad in [0.0, -10.0, double.infinity, double.nan]) {
        expect(
          () => RootBannerStyle(contentHeight: bad),
          throwsAssertionError,
          reason: 'contentHeight: $bad should be rejected',
        );
      }
    });
  });

  group('animation', () {
    testWidgets('shrinking the stack animates instead of snapping', (
      tester,
    ) async {
      final source = ValueNotifier<List<BannerSpec>>([spec, other, third]);
      addTearDown(source.dispose);
      await tester.pumpWidget(host(source));
      await tester.pumpAndSettle();

      double childTop() => tester.getTopLeft(find.byType(SizedBox).last).dy;
      expect(childTop(), 132.0); // 3 * 44

      source.value = [spec];
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      // Used to jump straight to 44: the visible height was clamped to the
      // already-shortened stack, leaving nothing to animate.
      expect(childTop(), greaterThan(100.0));

      await tester.pump(const Duration(milliseconds: 110));
      expect(childTop(), lessThan(132.0));
      expect(childTop(), greaterThan(44.0));

      await tester.pumpAndSettle();
      expect(childTop(), 44.0);
      expect(find.byType(BannerView), findsOne);
    });

    testWidgets('a metrics change resizes the strip instead of sliding it', (
      tester,
    ) async {
      // The animation duration used to survive the transition that asked for
      // it, so a rotation or a text-scale change re-ran the reveal animation on
      // a stack that had not moved.
      final source = ValueNotifier<List<BannerSpec>>([spec]);
      addTearDown(source.dispose);

      Widget at(double scale) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: RootBanner(source: source, child: const _Probe()),
        ),
      );
      double stripHeight() => tester.getTopLeft(find.byType(_Probe)).dy;

      await tester.pumpWidget(at(1.0));
      await tester.pumpAndSettle();
      expect(stripHeight(), 44.0);

      await tester.pumpWidget(at(2.0));
      expect(stripHeight(), 88.0, reason: 'landed in the frame that asked');
      await tester.pump(const Duration(milliseconds: 1));
      expect(stripHeight(), 88.0);
    });

    testWidgets('animateInsets: false keeps the app out of the animation', (
      tester,
    ) async {
      var builds = 0;
      final source = ValueNotifier<List<BannerSpec>>(const []);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RootBanner(
            source: source,
            style: const RootBannerStyle(animateInsets: false),
            child: _Probe(onBuild: () => builds++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = builds;
      source.value = [spec];
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(
        builds - before,
        lessThanOrEqualTo(1),
        reason: 'the app is rebuilt once for the new stack, not once per frame',
      );

      await tester.pumpAndSettle();
      // Opting out of the per-frame rebuild must not cost the correction itself.
      expect(tester.getSize(find.byType(_Probe)).height, 600.0 - 44.0);
    });

    testWidgets('animateInsets: true tracks the strip frame by frame', (
      tester,
    ) async {
      var builds = 0;
      final source = ValueNotifier<List<BannerSpec>>(const []);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RootBanner(
            source: source,
            child: _Probe(onBuild: () => builds++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = builds;
      source.value = [spec];
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(
        builds - before,
        greaterThan(3),
        reason: 'the default, documented',
      );
    });
  });

  group('resilience', () {
    testWidgets('large text scale grows the strip instead of clipping', (
      tester,
    ) async {
      final source = ValueNotifier<List<BannerSpec>>([spec]);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: RootBanner(source: source, child: const SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.renderObject<RenderParagraph>(
        find.text(spec.message),
      );
      // Was a 44pt box against 60pt of text: descenders were sliced off.
      expect(text.size.height, text.getMaxIntrinsicHeight(double.infinity));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long stack cannot squeeze the app off screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final source = ValueNotifier<List<BannerSpec>>([
        for (var i = 0; i < 20; i++) BannerSpec(message: 'b$i', priority: i),
      ]);
      addTearDown(source.dispose);

      await tester.pumpWidget(host(source));
      await tester.pumpAndSettle();

      // Was: RenderFlex overflowed by 480px and the child got a tight 0 height.
      expect(tester.takeException(), isNull);
      final childHeight = tester.getSize(find.byType(SizedBox).last).height;
      expect(childHeight, greaterThanOrEqualTo(200.0));
    });

    testWidgets('a host that is not full-bleed measures its own box', (
      tester,
    ) async {
      // The cap and the corrected size were both computed from the window, so a
      // host inside a panel sized its strip for a screen it did not have: ten
      // banners meant 264px of strip in a 200px box, and an overflow.
      final sizes = <Size>[];
      final source = ValueNotifier<List<BannerSpec>>([
        for (var i = 0; i < 10; i++) BannerSpec(message: 'b$i', priority: -i),
      ]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: RootBanner(
                source: source,
                child: _Probe(onSize: sizes.add),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Half of a 200px box, at 44px each.
      expect(find.byType(BannerView), findsExactly(2));
      expect(sizes.last, const Size(300.0, 200.0 - 88.0));
    });

    testWidgets('a narrow banner drops decoration instead of overflowing', (
      tester,
    ) async {
      final source = ValueNotifier<List<BannerSpec>>([
        BannerSpec(message: 'squeezed', onTap: () {}),
      ]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 70,
              height: 400,
              child: RootBanner(source: source, child: const SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Was: 'A RenderFlex overflowed by 26 pixels on the right'.
      expect(tester.takeException(), isNull);
      expect(find.text('squeezed'), findsOne);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('a source that mutates its list in place is still seen', (
      tester,
    ) async {
      // _resolve used to return the source's list by reference, so listEquals
      // compared it against itself and every update was dropped.
      final mutable = <BannerSpec>[spec];
      final source = ValueNotifier<List<BannerSpec>>(mutable);
      addTearDown(source.dispose);

      await tester.pumpWidget(host(source));
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsOne);

      mutable.add(other);
      source.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(BannerView), findsExactly(2));
    });

    testWidgets('a second host is caught rather than shifting the app down', (
      tester,
    ) async {
      final source = ValueNotifier<List<BannerSpec>>([spec]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RootBanner(
            source: source,
            child: RootBanner(source: source, child: const SizedBox.expand()),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isFlutterError);
      expect(error.toString(), contains('below another RootBanner'));
    });
  });

  group('renderer', () {
    testWidgets('a custom contentBuilder sees the corrected padding', (
      tester,
    ) async {
      // removePadding wrapped the builder's *result*, so a renderer reading
      // paddingOf(context) inline got the full inset for every banner and
      // pushed its content out of the box.
      tester.view.padding = const FakeViewPadding(top: 100);
      tester.view.viewPadding = const FakeViewPadding(top: 100);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      final seen = <double>[];
      final source = ValueNotifier<List<BannerSpec>>([spec, other]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RootBanner(
            source: source,
            style: RootBannerStyle(
              contentBuilder: (context, s) {
                seen.add(MediaQuery.paddingOf(context).top);
                return ColoredBox(
                  color: const Color(0xFF000000),
                  child: Text(s.message),
                );
              },
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topInset = 100 / tester.view.devicePixelRatio;
      expect(seen.first, closeTo(topInset, 0.01));
      expect(seen[1], 0.0, reason: 'the second banner has no status bar left');
    });

    testWidgets('severity colours can be re-mapped without a new renderer', (
      tester,
    ) async {
      const brand = Color(0xFF00FF00);
      final source = ValueNotifier<List<BannerSpec>>([
        const BannerSpec(message: 'warn', severity: BannerSeverity.warning),
      ]);
      addTearDown(source.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RootBanner(
            source: source,
            style: RootBannerStyle(
              contentBuilder: (context, s) => BannerView(
                spec: s,
                colors: (context, severity) =>
                    (background: brand, foreground: const Color(0xFF000000)),
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Material>(find.byType(Material).last).color, brand);
    });

    testWidgets('a warning is not painted in the brand colour', (tester) async {
      // primaryContainer made "warning" indistinguishable from the app's own
      // chrome, and identical to "error" under a red or amber seed.
      late ColorScheme scheme;
      late BannerColors warning;
      late BannerColors error;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFFFF8800)),
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              warning = BannerView.defaultColors(
                context,
                BannerSeverity.warning,
              );
              error = BannerView.defaultColors(context, BannerSeverity.error);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(warning.background, isNot(scheme.primaryContainer));
      expect(warning.background, isNot(error.background));
    });

    testWidgets('each banner is announced as it arrives', (tester) async {
      final handle = tester.ensureSemantics();
      final source = ValueNotifier<List<BannerSpec>>([spec]);
      addTearDown(source.dispose);
      await tester.pumpWidget(host(source));
      await tester.pumpAndSettle();

      // The flag has to sit on the node that carries the message, or a screen
      // reader has nothing to announce.
      expect(
        tester.getSemantics(find.text(spec.message)),
        isSemantics(label: spec.message, isLiveRegion: true),
      );
      // Not addTearDown: the handle check runs before tearDowns do.
      handle.dispose();
    });
  });
}
