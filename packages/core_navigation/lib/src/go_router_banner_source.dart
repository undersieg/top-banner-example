import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:banners/banners.dart';

/// Adapts a [GoRouter] to the banner package's [BannerSource].
///
/// This is the only place go_router and the banner package meet. It reads the
/// full matched route chain — outermost shell first, leaf last — collects the
/// [BannerMarker]s on it, and hands [BannerStack] the ordering.
///
/// Reading the chain rather than observing pushes and pops is what makes
/// arbitrary shell nesting free: depth is just a position in a flat list.
/// The caller owns this object and must [dispose] it; the constructor registers
/// a listener on the router's delegate, which outlives most widgets.
/// [AppBannerScope] does that for you.
class GoRouterBannerSource extends ChangeNotifier implements BannerSource {
  GoRouterBannerSource(this.router, {this.policy = BannerStack.order}) {
    router.routerDelegate.addListener(notifyListeners);
  }

  final GoRouter router;

  /// How the chain's banners become a stack. Defaults to [BannerStack.order].
  final BannerStackPolicy policy;

  /// Computed on read rather than cached: `currentConfiguration` is plain data,
  /// so there is no stale-snapshot window between a navigation and a rebuild.
  @override
  List<BannerSpec> get value => policy(
    router.routerDelegate.currentConfiguration.routes
        .whereType<BannerMarker>()
        .map((marker) => marker.banners),
  );

  @override
  void dispose() {
    // Before super.dispose(), so a navigation cannot notify a disposed notifier.
    // Relies on instance-method tear-offs of the same receiver comparing equal,
    // which Dart guarantees — keep this the only registration site, since
    // removeListener only removes one of N identical registrations.
    router.routerDelegate.removeListener(notifyListeners);
    super.dispose();
  }
}
