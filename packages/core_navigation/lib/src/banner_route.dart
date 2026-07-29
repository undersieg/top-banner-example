import 'package:go_router/go_router.dart';

import 'package:banners/banners.dart';

/// go_router routes that carry a [BannerMarker].
///
/// [GoRouterBannerSource] walks the full matched route chain and collects every
/// marker's banners, so it does not care whether a marker sits on a leaf route,
/// on an outer shell, or on a shell nested three levels deep.
///
/// [BannerRoute] and [BannerShellRoute] cover the common cases. For anything
/// else — `StatefulShellRoute`, your own `GoRoute` subclass — implement
/// [BannerMarker] on it and it is picked up for free. Note that
/// `StatefulShellBranch` is *not* a `RouteBase`, so it never appears in the
/// matched chain: put the marker on the branch's root route instead.
List<BannerSpec> _merge(BannerSpec? banner, List<BannerSpec> banners) =>
    List.unmodifiable(banner == null ? banners : [banner, ...banners]);

/// A [GoRoute] that declares banners for its own page.
///
/// Pass [banner] for the single-banner case, [banners] for several, or both
/// (in which case [banner] comes first).
///
/// go_router keeps the exact instance you construct in its match objects, so
/// the `is BannerMarker` test in `RootBanner` sees this subclass.
class BannerRoute extends GoRoute implements BannerMarker {
  BannerRoute({
    required super.path,
    BannerSpec? banner,
    List<BannerSpec> banners = const <BannerSpec>[],
    super.name,
    super.builder,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.onExit,
    super.routes = const <RouteBase>[],
    super.caseSensitive,
  }) : banners = _merge(banner, banners);

  @override
  final List<BannerSpec> banners;
}

/// A [ShellRoute] that declares banners for every route inside it.
///
/// Use this for section-wide banners ("you are in the beta area"). Markers
/// deeper in the chain stack on top rather than replacing it; see
/// [BannerSpec.priority] for ordering and [RootBannerStyle.maxVisible] to cap how
/// many show at once.
class BannerShellRoute extends ShellRoute implements BannerMarker {
  BannerShellRoute({
    required super.routes,
    BannerSpec? banner,
    List<BannerSpec> banners = const <BannerSpec>[],
    super.builder,
    super.pageBuilder,
    super.observers,
    super.navigatorKey,
    super.parentNavigatorKey,
    super.restorationScopeId,
    // Forwarded so a shell-level guard (auth sections, the common case) and
    // observer routing stay available; omitting them made this class a strict
    // downgrade from ShellRoute.
    super.redirect,
    super.notifyRootObserver,
  }) : banners = _merge(banner, banners);

  @override
  final List<BannerSpec> banners;
}
