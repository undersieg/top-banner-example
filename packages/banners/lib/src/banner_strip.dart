import 'package:flutter/foundation.dart' show listEquals;

import 'banner_spec.dart';

/// The bookkeeping behind the strip's grow-and-shrink animation: which stack is
/// being painted, which one it is heading for, and whether getting there is
/// animated.
///
/// Split out of the host widget deliberately. Every subtle bug in this feature
/// has been in these three lines of state rather than in the layout, and here
/// they can be driven directly in a unit test instead of inferred from pixel
/// positions after a `pump`.
class BannerStripTransition {
  List<BannerSpec> _painted = const [];
  List<BannerSpec> _target = const [];
  Duration _duration = Duration.zero;
  int _revision = 0;

  /// The stack to render. Outlives [target] while the strip shrinks past it.
  List<BannerSpec> get painted => _painted;

  /// The stack the current screen resolves to.
  List<BannerSpec> get target => _target;

  /// How long the move to [target] should take. Zero for the first resolution,
  /// so a deep link is simply already banner-ed, and zero again once settled,
  /// so a later metrics change (a rotation) snaps instead of sliding.
  Duration get duration => _duration;

  /// Incremented by every accepted [retarget].
  ///
  /// A frame callback scheduled to [finish] one transition can run after the
  /// next has already begun; comparing revisions is what stops it cutting the
  /// newer animation short.
  int get revision => _revision;

  bool get isSettled => listEquals(_painted, _target);

  /// Nothing left to hand over and nothing left to stop.
  bool get isIdle => isSettled && _duration == Duration.zero;

  /// Whether [retarget] with this stack would change anything.
  bool accepts(List<BannerSpec> next) => !listEquals(next, _target);

  /// Aims at [next], returning whether anything changed.
  bool retarget(List<BannerSpec> next, {required Duration duration}) {
    if (!accepts(next)) return false;
    _revision++;
    _target = next;
    _duration = duration;
    // Growing, or not animating at all: adopt the new stack right away, so new
    // banners are revealed as the strip grows.
    //
    // Shrinking: keep painting the outgoing stack and let the strip clip it
    // away, then swap in [finish]. Adopting it here instead would shorten the
    // painted stack in the same frame, and since the visible height is clamped
    // to what is painted there would be nothing left to animate — the old
    // behaviour, where N -> N-1 snapped.
    if (next.length >= _painted.length || duration == Duration.zero) {
      _painted = next;
    }
    return true;
  }

  /// Adopts [target] and stops animating, returning whether anything changed.
  ///
  /// Called when the strip reaches its target height.
  bool finish() {
    if (isIdle) return false;
    _painted = _target;
    _duration = Duration.zero;
    return true;
  }

  @override
  String toString() =>
      'BannerStripTransition(painted: ${_painted.length}, '
      'target: ${_target.length}, duration: $_duration, revision: $_revision)';
}
