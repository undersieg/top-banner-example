import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'banner_source.dart';
import 'banner_spec.dart';
import 'banner_strip.dart';
import 'banner_style.dart';

/// Ceiling on the share of the viewport the banner strip may occupy.
const double _maxStripFraction = 0.5;

/// Hosts a stack of banners above the entire app, driven by a [BannerSource].
///
/// Knows nothing about routing: it renders whatever stack the source reports
/// and re-renders when the source notifies. A routing adapter is what turns
/// route markers into that stack — with the core_navigation adapter, wrap this in
/// `AppBannerScope`, which publishes the source this reads:
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
/// Nothing is published from page state, so there is no registration lifecycle
/// to get wrong and no double-banner window during a route transition.
///
/// Mount exactly one per tree. Two would each paint the stack and each subtract
/// the status bar inset from the app below; a debug assert catches it.
class RootBanner extends StatefulWidget {
  const RootBanner({
    super.key,
    this.source,
    this.style = const RootBannerStyle(),
    required this.child,
  });

  /// Where the banners come from.
  ///
  /// Leave `null` to take it from the nearest [BannerSourceScope], which is what
  /// a routing adapter installs.
  final BannerSource? source;

  /// Appearance and timing. See [RootBannerStyle].
  final RootBannerStyle style;

  final Widget child;

  @override
  State<RootBanner> createState() => _RootBannerState();
}

/// Marks the subtree so a second [RootBanner] can be caught in debug.
class _RootBannerScope extends InheritedWidget {
  const _RootBannerScope({required super.child});

  @override
  bool updateShouldNotify(_RootBannerScope oldWidget) => false;
}

class _RootBannerState extends State<RootBanner> {
  final BannerStripTransition _strip = BannerStripTransition();

  BannerSource? _source;
  bool _syncScheduled = false;
  bool _initialSyncDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved here rather than in [build] so the subscription follows the
    // scope: an adapter that swaps its source — a router rebuilt on sign-in —
    // changes this dependency and lands here.
    _adoptSource(widget.source ?? BannerSourceScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(RootBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _adoptSource(widget.source ?? BannerSourceScope.maybeOf(context));
    }
    // maxVisible decides what a stack resolves to, so a change to it has to be
    // re-resolved even though the source is untouched.
    if (oldWidget.style.maxVisible != widget.style.maxVisible) {
      _sync(animate: false);
    }
  }

  @override
  void dispose() {
    _source?.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _adoptSource(BannerSource? source) {
    if (source == _source) return;
    _source?.removeListener(_onSourceChanged);
    _source = source;
    source?.addListener(_onSourceChanged);

    // If the source already knows the current screen, this picks up a deep link
    // immediately; if it does not yet, the post-frame sync below catches it.
    // Either way, no animation: on first paint the banners are simply already
    // there. setState is not needed (a build follows) and not allowed here.
    _sync(animate: false, notify: false);
    if (_initialSyncDone) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(animate: false);
      _initialSyncDone = true;
    });
  }

  /// Copied, never aliased: a source is free to hand back the same list it
  /// mutates in place, and comparing that against itself would make every
  /// update look like a no-op.
  List<BannerSpec> _resolve() {
    final stack = _source?.value ?? const <BannerSpec>[];
    final max = widget.style.maxVisible;
    return List<BannerSpec>.of(
      max != null && stack.length > max ? stack.take(max) : stack,
    );
  }

  /// A routing source typically notifies from inside the frame (a pop lands
  /// during `drawFrame`), and this host may be an *ancestor* of whatever is
  /// mid-build, so reacting synchronously would dirty an already-built element.
  /// Deferring unconditionally sidesteps every build-phase hazard at the cost of
  /// one frame, which the animation absorbs anyway.
  void _onSourceChanged() {
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

  void _sync({required bool animate, bool notify = true}) {
    final next = _resolve();
    if (!_strip.accepts(next)) return;
    final duration = animate ? widget.style.duration : Duration.zero;
    void apply() => _strip.retarget(next, duration: duration);
    notify ? setState(apply) : apply();
  }

  /// Hands the resolved stack over once the strip has reached its target height,
  /// and stops animating so a later metrics change — a rotation, a keyboard —
  /// resizes the strip outright instead of sliding it.
  ///
  /// Always deferred. `onEnd` fires synchronously from inside our own build when
  /// the transition has zero length (`AnimationController.forward` completes on
  /// the spot), and calling `setState` there re-dirties an element the framework
  /// has just cleaned — `assert(!_dirty)`. Idempotent, so the backstop in
  /// [build] and `onEnd` can both call it.
  void _finish() {
    if (_strip.isIdle) return;
    final revision = _strip.revision;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // A retarget between scheduling and running owns the strip now; finishing
      // on its behalf would cut the new animation short.
      if (!mounted || _strip.revision != revision || _strip.isIdle) return;
      setState(() {
        _strip.finish();
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Called from `build`, not from `didChangeDependencies`, for the same reason
  /// as [BannerSourceScope.missingSourceError]: throwing out of the latter
  /// abandons a half-mounted element that never gets a `dispose`.
  /// `test/leak_test.dart` catches the difference.
  bool _debugCheckSingleHost() {
    // getElementForInheritedWidgetOfExactType, not dependOnInherited...: this
    // runs in debug only and must not create a dependency that release builds
    // would not have.
    if (context.getElementForInheritedWidgetOfExactType<_RootBannerScope>() ==
        null) {
      return true;
    }
    throw FlutterError(
      'A RootBanner was mounted below another RootBanner.\n'
      'Both would paint the banner stack and both would subtract the status bar '
      'inset from the app below, so the second one shifts the whole app down. '
      'Mount exactly one, above the outermost Navigator you want banners over.',
    );
  }

  /// How many banners fit without squeezing the app content off screen.
  ///
  /// Without a cap, a long marker chain drives the strip past the viewport and
  /// [Expanded] resolves to a tight zero height — the app disappears behind its
  /// own banners. [RootBannerStyle.maxVisible] is the explicit control; this is
  /// the backstop for when there is none.
  int _fit(int count, double topInset, double contentHeight, double viewport) {
    if (count == 0) return 0;
    final room = viewport * _maxStripFraction - topInset;
    if (room < contentHeight) return 1;
    return math.min(count, room ~/ contentHeight);
  }

  double _heightFor(int count, double topInset, double contentHeight) =>
      count == 0 ? 0.0 : topInset + contentHeight * count;

  @override
  Widget build(BuildContext context) {
    assert(_debugCheckSingleHost());
    if (_source == null) throw BannerSourceScope.missingSourceError();

    final style = widget.style;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    // [contentHeight] is specified at text scale 1.0. Honouring the scale is
    // what keeps the message from being silently clipped at accessibility sizes:
    // a 14sp line is ~20dp, so a fixed 44dp box loses descenders past ~2.2x.
    final contentHeight = MediaQuery.textScalerOf(
      context,
    ).scale(style.contentHeight);

    return _RootBannerScope(
      // Measured against the box this host is actually given rather than the
      // window, so a host that is not full-bleed still caps the strip and
      // reports a size its children can believe.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : media.size.height;
          final viewportWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : media.size.width;

          final shownCount = _fit(
            _strip.painted.length,
            topInset,
            contentHeight,
            viewportHeight,
          );
          final targetCount = _fit(
            _strip.target.length,
            topInset,
            contentHeight,
            viewportHeight,
          );
          final shown = _strip.painted.take(shownCount).toList(growable: false);
          // Only the topmost banner adds the status bar inset; the rest sit
          // below it.
          final shownHeight = _heightFor(shownCount, topInset, contentHeight);
          final targetHeight = _heightFor(targetCount, topInset, contentHeight);

          Widget appContent(double visible) => MediaQuery(
            // Consume exactly what the stack covers, so nothing jumps at either
            // end. `viewInsets` is left alone: the keyboard still resizes
            // normally.
            data: media.copyWith(
              padding: media.padding.copyWith(
                top: math.max(0.0, topInset - visible),
              ),
              viewPadding: media.viewPadding.copyWith(
                top: math.max(0.0, media.viewPadding.top - visible),
              ),
              size: Size(
                viewportWidth,
                math.max(0.0, viewportHeight - visible),
              ),
            ),
            child: widget.child,
          );

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetHeight),
            duration: _strip.duration,
            curve: style.curve,
            onEnd: _finish,
            // Built once per stack change and handed through untouched, so no
            // MediaQuery dependent below rebuilds while the strip moves.
            child: style.animateInsets ? null : appContent(targetHeight),
            builder: (context, value, child) {
              // Clamped to what is painted, so a bouncy curve cannot overshoot
              // the OverflowBox and paint blank space.
              final visible = value.clamp(0.0, shownHeight);

              // Backstop: if the height is already where it is heading, no
              // transition runs and no onEnd arrives to hand over. Reached when
              // two stacks happen to need the same height.
              if (value == targetHeight) _finish();

              return Column(
                // The children list must keep a stable length and order:
                // swapping the slot out would remount the Expanded below it,
                // tearing down the whole Navigator.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: visible,
                    child: shown.isEmpty
                        ? null
                        : ClipRect(
                            // The stack keeps its full height while the strip
                            // grows, and is top-aligned, so banners already on
                            // screen hold position while a new one is revealed
                            // below them.
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: shownHeight,
                              maxHeight: shownHeight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < shown.length; i++)
                                    SizedBox(
                                      height:
                                          contentHeight +
                                          (i == 0 ? topInset : 0),
                                      child: _banner(
                                        context,
                                        shown[i],
                                        isTop: i == 0,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  Expanded(child: child ?? appContent(visible)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _banner(BuildContext context, BannerSpec spec, {required bool isTop}) {
    // Announced by a screen reader as it arrives, which is the point of a banner
    // nobody asked for. The flag has to land on the node carrying the message,
    // so it is merged with the renderer's own semantics rather than sitting
    // above them as a silent parent.
    final Widget content = MergeSemantics(
      child: Semantics(
        liveRegion: true,
        child: Builder(
          // The renderer has to run *under* the MediaQuery below, or one that
          // reads paddingOf itself insets twice.
          builder: (context) => widget.style.contentBuilder(context, spec),
        ),
      ),
    );
    // Below the topmost banner there is no status bar left to clear.
    return isTop
        ? content
        : MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: content,
          );
  }
}
