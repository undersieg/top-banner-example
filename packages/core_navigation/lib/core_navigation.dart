/// The app's navigation layer, and the only place a routing library appears.
///
/// go_router is an implementation detail of `lib/src/`: nothing exported from
/// here names one of its types, and no package above this one depends on it. That
/// is what makes it replaceable — a different router means rewriting `lib/src/`,
/// with route declarations, navigation calls, and banners untouched.
///
/// Wiring an app takes three things:
///
/// 1. describe the routes with [AppPageRoute] / [AppShellRoute] / [AppTabsRoute],
///    declaring banners where the screen is declared;
/// 2. build an [AppRouter] from them and hand `router.config` to
///    [MaterialApp.router];
/// 3. mount [AppBannerScope] once in the outermost shell, with a [RootBanner]
///    inside it.
///
/// Navigate through [AppNavigator]. Re-exports the `banners` package, so an app
/// depends on this one alone.
library;

export 'package:banners/banners.dart';

export 'src/app_navigator.dart' show AppCanPopBuilder, AppNavigator;
export 'src/app_route.dart'
    show
        AppPageRoute,
        AppRoute,
        AppShellRoute,
        AppTabBranch,
        AppTabs,
        AppTabsRoute;
export 'src/app_router.dart' show AppBannerScope, AppRouter;
