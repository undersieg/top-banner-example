import 'banner_marker.dart';
import 'banner_spec.dart';

/// Turns the banners declared along a chain of markers into the stack to render,
/// topmost first.
///
/// Receives the *grouped* input — one entry per marker, outermost first — because
/// depth cannot be recovered once the groups are flattened. A policy can
/// therefore reorder, dedupe, or drop by depth, not just by priority.
/// [BannerStack.order] is the default.
typedef BannerStackPolicy =
    List<BannerSpec> Function(Iterable<List<BannerSpec>> groupsOutermostFirst);

/// Ordering rules for a banner stack.
///
/// Pure data in, pure data out — no routing types — so a router adapter only
/// has to flatten its matched chain into groups and the policy stays testable
/// on its own.
abstract final class BannerStack {
  /// Orders the banners declared by a chain of markers, topmost first.
  ///
  /// [groupsOutermostFirst] is one entry per marker, outermost first and the
  /// leaf last — that ordering is what makes depth meaningful.
  ///
  /// Ordering: highest [BannerSpec.priority] wins; then the deepest marker, so
  /// a page's own banner sits above its section's; then declaration order
  /// within a single marker.
  static List<BannerSpec> order(
    Iterable<List<BannerSpec>> groupsOutermostFirst,
  ) {
    final entries = <({BannerSpec spec, int depth, int order})>[];
    var depth = 0;
    for (final group in groupsOutermostFirst) {
      var order = 0;
      for (final spec in group) {
        entries.add((spec: spec, depth: depth, order: order++));
      }
      depth++;
    }

    // Sorting on an explicit (priority, depth, order) key rather than relying
    // on sort stability: List.sort is not stable in Dart, so equal-priority
    // banners would otherwise be free to swap places between runs.
    entries.sort((a, b) {
      final byPriority = b.spec.priority.compareTo(a.spec.priority);
      if (byPriority != 0) return byPriority;
      final byDepth = b.depth.compareTo(a.depth);
      return byDepth != 0 ? byDepth : a.order.compareTo(b.order);
    });

    return [for (final entry in entries) entry.spec];
  }

  /// [order] over a chain of markers, for adapters whose chain is already a
  /// list of markers.
  static List<BannerSpec> ofMarkers(
    Iterable<BannerMarker> markersOutermostFirst,
  ) => order(markersOutermostFirst.map((marker) => marker.banners));
}
