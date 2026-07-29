import 'banner_spec.dart';

/// The marker. Attach it to whatever your router uses to describe a screen.
///
/// Deliberately free of any routing types: the banner package defines what a
/// marker *is*, and a router-specific adapter decides what carries it. The
/// core_navigation adapter attaches it to its route types, so a marker can sit
/// on a leaf route or on a shell nested any number of levels deep.
abstract interface class BannerMarker {
  /// Banners this marker declares, in declaration order. Empty for none.
  ///
  /// Several markers along one chain stack, so a page can end up showing its
  /// own banners plus its section's.
  List<BannerSpec> get banners;
}
