import 'package:flutter/widgets.dart';

/// Visual weight of a banner.
///
/// The spec stays theme-agnostic: the renderer maps severity onto the app's
/// [ColorScheme], so a banner declared in the router still follows the theme.
enum BannerSeverity { info, success, warning, error }

/// What to show in the root banner.
///
/// Immutable and value-equal, which is what lets `RootBanner` skip work when a
/// navigation resolves to the same banner.
///
/// Note on [onTap]: closures do not compare equal across rebuilds. Specs are
/// meant to live on route definitions (built once, at router construction), so
/// this is a non-issue in practice. If you build specs on the fly, hoist the
/// callback into a `static` or a field so equality keeps working.
@immutable
class BannerSpec {
  const BannerSpec({
    required this.message,
    this.severity = BannerSeverity.info,
    this.icon,
    this.onTap,
    this.priority = 0,
  });

  final String message;

  final BannerSeverity severity;

  /// Overrides the default icon for [severity]. Leave `null` for the default.
  final IconData? icon;

  final VoidCallback? onTap;

  /// Orders the stack when several banners are active: higher sits on top.
  ///
  /// Ties go to the deepest route in the matched chain, so a page's own banner
  /// sits above its section's. Also decides who survives
  /// `RootBanner.maxVisible`.
  final int priority;

  @override
  bool operator ==(Object other) =>
      other is BannerSpec &&
      other.message == message &&
      other.severity == severity &&
      other.icon == icon &&
      other.onTap == onTap &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(message, severity, icon, onTap, priority);

  @override
  String toString() => 'BannerSpec($severity, "$message", priority: $priority)';
}
