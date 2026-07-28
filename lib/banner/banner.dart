/// Root banner driven by a marker on the route.
///
/// 1. Mark a route: `BannerRoute(path: '/promo', banner: BannerSpec(...))`,
///    or a whole section: `BannerShellRoute(banner: ..., routes: [...])`.
/// 2. Host it once, at the root: `MaterialApp.router(builder: (context, child)
///    => RootBanner(router: _router, child: child!))`.
///
/// Works at any nesting depth, including inner `ShellRoute`s.
library;

export 'banner_route.dart' show BannerMarker, BannerRoute, BannerShellRoute;
export 'banner_spec.dart' show BannerSeverity, BannerSpec;
export 'banner_view.dart' show BannerView;
export 'root_banner.dart' show BannerContentBuilder, RootBanner;
