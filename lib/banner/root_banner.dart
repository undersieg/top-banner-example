import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'banner_route.dart';
import 'banner_spec.dart';
import 'banner_view.dart';

/// Builds one banner body. See [BannerView] for the sizing contract.
typedef BannerContentBuilder =
    Widget Function(BuildContext context, BannerSpec spec);

/// Hosts a stack of banners above the entire app, driven by [BannerMarker]s on
/// routes.
///
/// Mount it in [MaterialApp.router]'s `builder`, which is the outermost point
/// that still sits below `Theme`/`MediaQuery` and above every shell:
///
/// ```dart
/// MaterialApp.router(
///   routerConfig: _router,
///   builder: (context, child) =>
///       RootBanner(router: _router, child: child!),
/// )
/// ```
///
/// It reads the full matched route chain from the router on every navigation,
/// so markers are found whether they sit on a leaf route or on a shell nested
/// any number of levels deep, and several of them stack. Nothing is published
/// from page state, so there is no registration lifecycle to get wrong and no
/// double-banner window during a route transition.
class RootBanner extends StatefulWidget {
  const RootBanner({
    super.key,
    required this.router,
    required this.child,
    this.contentHeight = 44.0,
    this.maxVisible,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.contentBuilder = _defaultContent,
  }) : assert(maxVisible == null || maxVisible > 0);

  /// The same [GoRouter] instance passed to `MaterialApp.router`.
  ///
  /// Passed explicitly on purpose: `GoRouter.of(context)` is not reachable from
  /// the `builder` callback, because `InheritedGoRouter` is installed *below*
  /// it.
  final GoRouter router;

  final Widget child;

  /// Height of one banner, *excluding* the status bar inset that the topmost
  /// banner adds on top of it.
  ///
  /// Fixed rather than measured so the layout below can be adjusted exactly in
  /// step with the animation. Banner text is single-line and ellipsised.
  final double contentHeight;

  /// Caps how many banners stack at once, keeping the highest priority ones.
  ///
  /// `null` (the default) means no cap: every marker in the chain shows, so
  /// stacking three markers costs three banners' worth of viewport. Pass `1`
  /// for "most important only", which makes a leaf marker fully override the
  /// section it lives in.
  final int? maxVisible;

  final Duration duration;

  final Curve curve;

  final BannerContentBuilder contentBuilder;

  static Widget _defaultContent(BuildContext context, BannerSpec spec) =>
      BannerView(spec: spec);

  /// Collects and orders the banners a matched route chain declares.
  ///
  /// The chain runs outermost shell first, leaf last. Ordering, topmost first:
  /// highest [BannerSpec.priority]; then the deepest marker, so a page's own
  /// banner sits above its section's; then declaration order within one marker.
  ///
  /// Exposed so routing rules can be unit-tested without pumping a widget.
  static List<BannerSpec> resolve(
    Iterable<RouteBase> matchedChain, {
    int? maxVisible,
  }) {
    final entries = <({BannerSpec spec, int depth, int order})>[];
    var depth = 0;
    for (final marker in matchedChain.whereType<BannerMarker>()) {
      var order = 0;
      for (final spec in marker.banners) {
        entries.add((spec: spec, depth: depth, order: order++));
      }
      depth++;
    }

    entries.sort((a, b) {
      final byPriority = b.spec.priority.compareTo(a.spec.priority);
      if (byPriority != 0) return byPriority;
      final byDepth = b.depth.compareTo(a.depth);
      return byDepth != 0 ? byDepth : a.order.compareTo(b.order);
    });

    final specs = [for (final entry in entries) entry.spec];
    if (maxVisible != null && specs.length > maxVisible) {
      return specs.sublist(0, maxVisible);
    }
    return specs;
  }

  @override
  State<RootBanner> createState() => _RootBannerState();
}

class _RootBannerState extends State<RootBanner> {
  /// What is rendered. Outlives [_resolved] while collapsing to zero height.
  List<BannerSpec> _shown = const [];

  /// What the current route resolves to.
  List<BannerSpec> _resolved = const [];

  /// False while collapsing, so [_shown] can still be painted.
  bool _expanded = false;

  /// Zero for the first resolution, so a deep link is simply already banner-ed.
  Duration _duration = Duration.zero;

  bool _syncScheduled = false;
  bool _initialSyncDone = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRouteChanged);

    // The Router below us has usually not parsed the initial route yet, so this
    // is normally empty; the post-frame sync below is what catches a deep link.
    _resolved = _resolve();
    _shown = _resolved;
    _expanded = _resolved.isNotEmpty;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(animate: false);
      _initialSyncDone = true;
    });
  }

  @override
  void didUpdateWidget(RootBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      widget.router.routerDelegate.addListener(_onRouteChanged);
    }
    if (oldWidget.maxVisible != widget.maxVisible ||
        oldWidget.router != widget.router) {
      _sync(animate: false);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  List<BannerSpec> _resolve() => RootBanner.resolve(
    widget.router.routerDelegate.currentConfiguration.routes,
    maxVisible: widget.maxVisible,
  );

  /// The delegate notifies from inside the frame (pops land during `drawFrame`),
  /// and this widget is an *ancestor* of the Router that is mid-build, so
  /// reacting synchronously would dirty an already-built element. Deferring
  /// unconditionally sidesteps every build-phase hazard at the cost of one
  /// frame, which the animation absorbs anyway.
  void _onRouteChanged() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      _sync(animate: _initialSyncDone);
    });
    // A frame is normally already pending; this covers the idle case, where a
    // post-frame callback would otherwise never run.
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _sync({required bool animate}) {
    final next = _resolve();
    if (listEquals(next, _resolved)) return;
    setState(() {
      _resolved = next;
      _duration = animate ? widget.duration : Duration.zero;
      _expanded = next.isNotEmpty;
      // On the way out, keep painting the old stack until it has collapsed.
      if (_expanded) _shown = next;
    });
  }

  void _onCollapsed() {
    if (!_expanded && _shown.isNotEmpty && mounted) {
      setState(() => _shown = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final shown = _shown;
    // Only the topmost banner adds the status bar inset; the rest sit below it.
    final fullHeight = shown.isEmpty
        ? 0.0
        : topInset + widget.contentHeight * shown.length;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: _expanded ? fullHeight : 0.0),
      duration: _duration,
      curve: widget.curve,
      onEnd: _onCollapsed,
      builder: (context, value, _) {
        final visible = value.clamp(0.0, fullHeight);

        return Column(
          // The children list must keep a stable length and order: swapping the
          // slot out would remount the Expanded below it, tearing down the
          // whole Navigator.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: visible,
              child: shown.isEmpty
                  ? null
                  : ClipRect(
                      // The stack keeps its full height while the strip grows,
                      // and is top-aligned, so banners already on screen hold
                      // position while a new one is revealed below them.
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: fullHeight,
                        maxHeight: fullHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < shown.length; i++)
                              SizedBox(
                                height:
                                    widget.contentHeight +
                                    (i == 0 ? topInset : 0.0),
                                child: i == 0
                                    ? widget.contentBuilder(context, shown[i])
                                    // Below the topmost banner there is no
                                    // status bar left to clear.
                                    : MediaQuery.removePadding(
                                        context: context,
                                        removeTop: true,
                                        child: widget.contentBuilder(
                                          context,
                                          shown[i],
                                        ),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: MediaQuery(
                // Consume exactly what the stack covers, tracking the
                // animation, so nothing jumps at either end. `viewInsets` is
                // left alone: the keyboard still resizes normally.
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    top: math.max(0.0, topInset - visible),
                  ),
                  viewPadding: media.viewPadding.copyWith(
                    top: math.max(0.0, media.viewPadding.top - visible),
                  ),
                  size: Size(
                    media.size.width,
                    math.max(0.0, media.size.height - visible),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}
