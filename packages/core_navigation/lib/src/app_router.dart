import 'package:banners/banners.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_route.dart';
import 'banner_route.dart';
import 'go_router_banner_source.dart';

/// Builds the app's router from its [AppRoute] tree.
///
/// This class, and the two other files in this directory, are the only code that
/// knows go_router exists. Everything above it — route declarations, navigation,
/// banners — is expressed in this package's own types, so swapping the router
/// means rewriting `lib/src/` and nothing else.
///
/// ```dart
/// final router = AppRouter(routes: appRoutes);
/// ...
/// MaterialApp.router(routerConfig: router.config);
/// ```
///
/// The caller owns it and must [dispose] it.
class AppRouter {
  AppRouter({required List<AppRoute> routes, String initialLocation = '/'})
    : _router = GoRouter(
        routes: _mapAll(routes),
        initialLocation: initialLocation,
      );

  final GoRouter _router;

  /// Hand this to [MaterialApp.router].
  ///
  /// `RouterConfig` is a Flutter type, so this says nothing about which router is
  /// underneath — which is the point.
  RouterConfig<Object> get config => _router;

  void dispose() => _router.dispose();

  static List<RouteBase> _mapAll(List<AppRoute> routes) => [
    for (final route in routes) _map(route),
  ];

  /// Exhaustive over the sealed hierarchy, so a new [AppRoute] type is a compile
  /// error here rather than a route that silently never matches.
  ///
  /// A node that declares nothing is mapped to a plain route rather than to a
  /// marker carrying an empty list. Both resolve to the same banners, but a
  /// marker per shell puts an empty group in the chain for every level of
  /// nesting — which a [BannerStackPolicy] then has to see through, and which
  /// makes "depth" count shells that had no opinion.
  static RouteBase _map(AppRoute route) => switch (route) {
    AppPageRoute() when route.banners.isEmpty => GoRoute(
      path: route.path,
      name: route.name,
      builder: (context, state) => route.builder(context),
      routes: _mapAll(route.children),
    ),
    AppPageRoute() => BannerRoute(
      path: route.path,
      name: route.name,
      banners: route.banners,
      builder: (context, state) => route.builder(context),
      routes: _mapAll(route.children),
    ),
    AppShellRoute() when route.banners.isEmpty => ShellRoute(
      builder: (context, state, child) => route.builder(context, child),
      routes: _mapAll(route.children),
    ),
    AppShellRoute() => BannerShellRoute(
      banners: route.banners,
      builder: (context, state, child) => route.builder(context, child),
      routes: _mapAll(route.children),
    ),
    AppTabsRoute() => StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => route.builder(
        context,
        AppTabs(
          view: shell,
          currentIndex: shell.currentIndex,
          // Wrapped, not torn off: goBranch takes an optional named argument, so
          // its type is not ValueChanged<int>.
          goToBranch: (index) => shell.goBranch(index),
        ),
      ),
      branches: [
        for (final branch in route.branches)
          StatefulShellBranch(routes: _mapAll(branch.routes)),
      ],
    ),
  };
}

/// Publishes the current screen's banners to the [RootBanner] below it.
///
/// Mount it in the outermost shell's builder, above every inner shell and page,
/// with the host inside it:
///
/// ```dart
/// AppShellRoute(
///   builder: (context, child) => AppBannerScope(
///     child: RootBanner(child: AppChrome(child: child)),
///   ),
///   children: [...],
/// )
/// ```
///
/// Two widgets rather than one on purpose: this one resolves, [RootBanner]
/// renders. A combined host had to accept a [RootBannerStyle] it never read and
/// forward it, which is exactly the parameter that drifts out of step.
///
/// To sit above the root [Navigator] as well — so root-navigator routes and
/// `useRootNavigator: true` dialogs cannot cover the banners — mount it in
/// [MaterialApp.router]'s `builder` instead. Nothing is in scope above the Router
/// yet, so that is the one case where [router] has to be passed.
class AppBannerScope extends StatefulWidget {
  const AppBannerScope({
    super.key,
    required this.child,
    this.router,
    this.policy = BannerStack.order,
  });

  final Widget child;

  /// Leave `null` to find the router from context. Required only when mounting
  /// above the Router.
  final AppRouter? router;

  /// How the declared banners become a stack, topmost first. Defaults to
  /// [BannerStack.order]: priority, then depth, then declaration order.
  final BannerStackPolicy policy;

  @override
  State<AppBannerScope> createState() => _AppBannerScopeState();
}

class _AppBannerScopeState extends State<AppBannerScope> {
  /// Typed as the implementation, not as [BannerSource]: this owns the source's
  /// lifetime, and `ValueListenable` has no `dispose` to call.
  GoRouterBannerSource? _source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _adoptRouter();
  }

  @override
  void didUpdateWidget(AppBannerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router ||
        oldWidget.policy != widget.policy) {
      _adoptRouter();
    }
  }

  /// [GoRouter.maybeOf] registers an inherited dependency, so a router swapped in
  /// above us — a rebuilt router on sign-in — arrives here through
  /// [didChangeDependencies] as well.
  void _adoptRouter() {
    final explicit = widget.router;
    final router = explicit?._router ?? GoRouter.maybeOf(context);
    if (router == null) return; // Reported from build.
    if (_source?.router == router && _source?.policy == widget.policy) return;
    // Safe to dispose while the RootBanner below still listens: removeListener on
    // a disposed ChangeNotifier is explicitly legal, and the new scope makes it
    // re-subscribe on its next didChangeDependencies.
    _source?.dispose();
    _source = GoRouterBannerSource(router, policy: widget.policy);
  }

  /// Reported from `build`, not from `didChangeDependencies`: throwing out of the
  /// latter abandons a half-mounted element that never gets a `dispose`, so the
  /// error path itself leaks. `test/leak_test.dart` catches the difference.
  Never _noRouter() {
    throw FlutterError(
      'AppBannerScope found no router above it.\n'
      'Mount it below the Router — the outermost shell builder is the usual '
      'spot. If you are mounting it in MaterialApp.router\'s builder, that '
      'callback sits above the Router and nothing is in scope there yet, so pass '
      'router: explicitly.',
    );
  }

  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) _noRouter();
    return BannerSourceScope(source: source, child: widget.child);
  }
}
