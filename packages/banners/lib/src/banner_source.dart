import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'banner_spec.dart';

/// Where [RootBanner] gets its banners from: the ordered stack for the screen
/// currently on display, topmost first, plus a notification when it changes.
///
/// This is the whole contract between the banner package and whatever routing
/// library an app uses. `ValueListenable` is deliberate — it is a Flutter
/// built-in, so nothing here has to know which routing library an app uses.
typedef BannerSource = ValueListenable<List<BannerSpec>>;

/// Provides a [BannerSource] to the [RootBanner] below it.
///
/// A routing adapter installs this; see the core_navigation adapter's
/// `AppBannerScope`, which creates the source and publishes it.
class BannerSourceScope extends InheritedWidget {
  const BannerSourceScope({
    super.key,
    required this.source,
    required super.child,
  });

  final BannerSource source;

  static BannerSource? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BannerSourceScope>()?.source;

  /// The nearest [BannerSource], or [missingSourceError] if there is none.
  static BannerSource of(BuildContext context) =>
      maybeOf(context) ?? (throw missingSourceError());

  /// Says what to do when no scope was found.
  ///
  /// Separate from [of] so the host can report it from `build` rather than from
  /// `didChangeDependencies`: throwing out of the latter abandons a half-mounted
  /// element, which then never gets a `dispose` — an error path that leaks.
  ///
  /// Deliberately names no routing library: an adapter for any router should be
  /// able to surface this without pointing users at a package they do not
  /// depend on.
  static FlutterError missingSourceError() => FlutterError(
    'No BannerSourceScope found above this RootBanner.\n'
    'Wrap it in a BannerSourceScope, or pass source: to RootBanner directly. '
    'A routing adapter normally installs the scope for you — with the '
    'core_navigation adapter, that is AppBannerScope.',
  );

  /// Note there is deliberately no `stackOf(context)` helper. It would read
  /// [BannerSource.value] once and never update, because [updateShouldNotify]
  /// only fires when the source *object* changes, not its contents. Watch the
  /// stack with `ValueListenableBuilder(valueListenable: of(context), ...)`
  /// instead — being a plain `ValueListenable` is the point of this seam.
  @override
  bool updateShouldNotify(BannerSourceScope oldWidget) =>
      oldWidget.source != source;
}
