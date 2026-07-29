import 'package:core_navigation/core_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:top_banner_example/main.dart';

/// The demo app's own wiring: banners declared at every shell depth, and the back
/// arrow that has to reach into all of them.
///
/// Note what this file does *not* import: go_router. The app describes its routes
/// with core_navigation's own types, so the test drives it the same way — and the
/// example's pubspec no longer lists the dependency, which makes that a compile
/// error rather than a convention.
void main() {
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
      expect(
        find.text('No banner declared on this route, so no banner.'),
        findsOne,
      );
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

      AppNavigator.of(tester.element(find.text('Inbox tab'))).push('/promo');
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOne);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Inbox tab'), findsOne);
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('example app', () {
    testWidgets('main.dart wiring resolves banners at every depth', (
      tester,
    ) async {
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Shell 1's AppBar title is present on every route, so it is a stable
      // navigation context for the whole walk.
      Future<void> go(String location) async {
        AppNavigator.of(
          tester.element(find.text('Shell 1 — app chrome')),
        ).go(location);
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

      // Shell 2's banner alone.
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

      // Tabs: declared on one branch's root route only.
      await go('/tabs/inbox');
      expect(find.byType(BannerView), findsOne);
      expect(find.text(Banners.inbox.message), findsOne);

      await go('/tabs/profile');
      expect(find.byType(BannerView), findsNothing);
    });
  });
}
