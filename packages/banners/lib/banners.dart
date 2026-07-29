/// Root banner rendering, independent of any routing library.
///
/// Depends on Flutter only. It renders whatever stack a [BannerSource] reports
/// and re-renders when that source notifies; nothing here knows how routes work.
/// Bringing this into an app therefore needs a routing adapter — see
/// the `core_navigation` package for this repository's.
///
/// The seam is deliberately a plain `ValueListenable<List<BannerSpec>>`, so an
/// adapter needs no base class from here:
///
/// - declare banners by implementing [BannerMarker] on whatever describes a
///   screen in your router;
/// - flatten the current chain of markers, outermost first, through
///   [BannerStack];
/// - publish the result as a [BannerSource] via [BannerSourceScope].
library;

export 'src/banner_marker.dart' show BannerMarker;
export 'src/banner_source.dart' show BannerSource, BannerSourceScope;
export 'src/banner_spec.dart' show BannerSeverity, BannerSpec;
export 'src/banner_stack.dart' show BannerStack, BannerStackPolicy;
export 'src/banner_strip.dart' show BannerStripTransition;
export 'src/banner_style.dart' show BannerContentBuilder, RootBannerStyle;
export 'src/banner_view.dart'
    show BannerColorResolver, BannerColors, BannerView;
export 'src/root_banner.dart' show RootBanner;
