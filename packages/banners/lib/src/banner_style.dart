import 'package:flutter/widgets.dart';

import 'banner_spec.dart';
import 'banner_view.dart';

/// Builds one banner body. See [BannerView] for the sizing contract.
typedef BannerContentBuilder =
    Widget Function(BuildContext context, BannerSpec spec);

/// How the banner strip looks and moves.
///
/// One value object rather than a handful of parameters, so a routing adapter
/// can forward the whole thing without restating any of it. Repeating the
/// parameters — and their defaults — in every wrapper is how the two ends drift
/// apart; there is exactly one place each default is written.
@immutable
final class RootBannerStyle {
  const RootBannerStyle({
    this.contentHeight = 44.0,
    this.maxVisible,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.contentBuilder = defaultContentBuilder,
    this.animateInsets = true,
  }) : assert(
         maxVisible == null || maxVisible > 0,
         'maxVisible must be at least 1; use an empty source for no banners.',
       ),
       assert(
         contentHeight > 0 && contentHeight < double.infinity,
         'contentHeight must be a positive, finite number of logical pixels.',
       );

  /// Height of one banner at text scale 1.0, *excluding* the status bar inset
  /// that the topmost banner adds on top of it.
  ///
  /// Fixed rather than measured so the layout below can be adjusted exactly in
  /// step with the animation. Banner text is single-line and ellipsised. Scaled
  /// by [MediaQuery.textScalerOf] at build time, so accessibility text sizes
  /// grow the strip instead of clipping the message.
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

  /// Whether the padding and size handed to the app below track the strip
  /// frame by frame.
  ///
  /// `true` (the default) is what keeps content from jumping at either end of
  /// the transition, and costs a rebuild of every [MediaQuery] dependent below
  /// — a `Scaffold`, a `SafeArea` — on each of those frames.
  ///
  /// `false` builds the app content once per stack change, against the settled
  /// insets, and hands the same widget through untouched while the strip moves:
  /// nothing below rebuilds during the transition. The trade is that for those
  /// ~200ms `MediaQuery.sizeOf` reports the final height while the box is still
  /// sliding, so anything laying itself out from `size` rather than from its
  /// constraints will be off by up to one banner.
  final bool animateInsets;

  /// The default renderer, so a wrapper can fall back to it explicitly.
  static Widget defaultContentBuilder(BuildContext context, BannerSpec spec) =>
      BannerView(spec: spec);

  RootBannerStyle copyWith({
    double? contentHeight,
    int? maxVisible,
    Duration? duration,
    Curve? curve,
    BannerContentBuilder? contentBuilder,
    bool? animateInsets,
  }) => RootBannerStyle(
    contentHeight: contentHeight ?? this.contentHeight,
    maxVisible: maxVisible ?? this.maxVisible,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    contentBuilder: contentBuilder ?? this.contentBuilder,
    animateInsets: animateInsets ?? this.animateInsets,
  );

  @override
  bool operator ==(Object other) =>
      other is RootBannerStyle &&
      other.contentHeight == contentHeight &&
      other.maxVisible == maxVisible &&
      other.duration == duration &&
      other.curve == curve &&
      other.contentBuilder == contentBuilder &&
      other.animateInsets == animateInsets;

  @override
  int get hashCode => Object.hash(
    contentHeight,
    maxVisible,
    duration,
    curve,
    contentBuilder,
    animateInsets,
  );
}
