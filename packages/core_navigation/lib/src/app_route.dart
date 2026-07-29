import 'package:banners/banners.dart';
import 'package:flutter/widgets.dart';

/// Folds the [AppPageRoute.banner] shorthand into the list, so [AppRoute.banners]
/// is the single answer to "what does this node declare".
List<BannerSpec> _merge(BannerSpec? banner, List<BannerSpec> banners) =>
    List.unmodifiable(banner == null ? banners : [banner, ...banners]);

/// One node in the app's route tree.
///
/// This is the app-facing description of navigation: paths, chrome, tabs, and
/// the banners a screen declares. It names no routing library, so replacing the
/// one underneath is a change to [AppRouter] and nothing else.
///
/// `sealed`, so [AppRouter]'s mapping is exhaustive by the compiler rather than
/// by a default branch that silently drops a route type added later.
sealed class AppRoute {
  const AppRoute();

  /// Banners this node declares, in declaration order.
  ///
  /// A node's banners apply to it and to everything nested inside it, so a
  /// banner on a shell covers its whole section. See [BannerStack] for how
  /// several of them stack.
  List<BannerSpec> get banners;
}

/// A screen at [path].
final class AppPageRoute extends AppRoute {
  AppPageRoute({
    required this.path,
    required this.builder,
    this.name,
    BannerSpec? banner,
    List<BannerSpec> banners = const <BannerSpec>[],
    this.children = const <AppRoute>[],
  }) : banners = _merge(banner, banners);

  final String path;

  /// Optional name, for navigating by name rather than by path.
  final String? name;

  /// Note there is no `state` argument: route arguments are deliberately out of
  /// scope here, since every router models them differently and this app does
  /// not use them. Adding them is the one place this abstraction would grow.
  final Widget Function(BuildContext context) builder;

  /// Everything this route declares: the `banner` shorthand first, then
  /// `banners`.
  @override
  final List<BannerSpec> banners;

  /// Routes nested under this one.
  final List<AppRoute> children;
}

/// Chrome wrapped around everything nested inside it, on its own Navigator.
///
/// A push inside a shell replaces the shell's content and leaves the chrome up.
final class AppShellRoute extends AppRoute {
  AppShellRoute({
    required this.builder,
    required this.children,
    BannerSpec? banner,
    List<BannerSpec> banners = const <BannerSpec>[],
  }) : banners = _merge(banner, banners);

  final Widget Function(BuildContext context, Widget child) builder;

  final List<AppRoute> children;

  /// Everything this shell declares, and so everything nested inside it
  /// inherits: the `banner` shorthand first, then `banners`.
  @override
  final List<BannerSpec> banners;
}

/// Tabs: one Navigator per branch, so each tab keeps its own stack.
///
/// Carries no banners of its own. A banner here would have to be declared on the
/// container that holds every tab, and the routing libraries underneath do not
/// all put that container in the matched chain — go_router's branches are not
/// routes at all. Declare the banner on the branch's first route instead, which
/// is both portable and more precise.
final class AppTabsRoute extends AppRoute {
  const AppTabsRoute({required this.builder, required this.branches});

  final Widget Function(BuildContext context, AppTabs tabs) builder;

  final List<AppTabBranch> branches;

  @override
  List<BannerSpec> get banners => const <BannerSpec>[];
}

/// One tab's stack.
final class AppTabBranch {
  const AppTabBranch({required this.routes});

  /// The branch's own routes. The first one is its root, and the place to
  /// declare a banner that should cover the whole tab.
  final List<AppRoute> routes;
}

/// What a tab shell is handed: the tab views, which one is showing, and how to
/// switch.
@immutable
final class AppTabs {
  const AppTabs({
    required this.view,
    required this.currentIndex,
    required this.goToBranch,
  });

  /// The branch Navigators, with the current one on top. Put this where the tab
  /// content belongs.
  final Widget view;

  final int currentIndex;

  /// Switches tabs, keeping each branch's own stack.
  final ValueChanged<int> goToBranch;
}
