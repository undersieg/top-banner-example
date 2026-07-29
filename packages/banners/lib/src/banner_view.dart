import 'package:flutter/material.dart';

import 'banner_spec.dart';

/// The pair of colours one banner is painted in.
typedef BannerColors = ({Color background, Color foreground});

/// Maps a severity onto colours, given the theme in scope.
///
/// Pass one to [BannerView.colors] to re-map severities without replacing the
/// renderer — brand colours, a house warning yellow, higher contrast.
typedef BannerColorResolver =
    BannerColors Function(BuildContext context, BannerSeverity severity);

/// Default banner renderer.
///
/// Contract for any replacement passed to `RootBannerStyle.contentBuilder`: you
/// are handed a box of exactly `MediaQuery.paddingOf(context).top +
/// RootBannerStyle.contentHeight` and tight constraints, so fill it. Paint your
/// background across the whole box (so colour runs up behind the status bar) and
/// inset your *content* by the top padding yourself, as this does.
class BannerView extends StatelessWidget {
  const BannerView({super.key, required this.spec, this.colors});

  final BannerSpec spec;

  /// Severity-to-colour mapping. Defaults to [defaultColors].
  final BannerColorResolver? colors;

  static IconData _defaultIcon(BannerSeverity severity) => switch (severity) {
    BannerSeverity.info => Icons.info_outline,
    BannerSeverity.success => Icons.check_circle_outline,
    BannerSeverity.warning => Icons.warning_amber_outlined,
    BannerSeverity.error => Icons.error_outline,
  };

  /// The built-in mapping.
  ///
  /// `info` and `error` come from the [ColorScheme], which is where the theme
  /// already has an opinion. `success` and `warning` do not: Material 3 has no
  /// role for either, and borrowing `primaryContainer` or `tertiaryContainer`
  /// paints a warning in whatever the brand colour happens to be — an amber
  /// seed makes "error" and "warning" indistinguishable. These use fixed hues
  /// per brightness instead, and [BannerView.colors] is there for apps that
  /// want their own.
  static BannerColors defaultColors(
    BuildContext context,
    BannerSeverity severity,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    return switch (severity) {
      BannerSeverity.info => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
      BannerSeverity.error => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
      BannerSeverity.warning =>
        isLight
            ? (
                background: const Color(0xFFFFE082),
                foreground: const Color(0xFF3E2E00),
              )
            : (
                background: const Color(0xFF574500),
                foreground: const Color(0xFFFFE082),
              ),
      BannerSeverity.success =>
        isLight
            ? (
                background: const Color(0xFFB7EFC5),
                foreground: const Color(0xFF06281A),
              )
            : (
                background: const Color(0xFF0F3D26),
                foreground: const Color(0xFFB7EFC5),
              ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = (colors ?? defaultColors)(context, spec.severity);
    // Read the *unadjusted* padding: this widget is rendered outside the
    // MediaQuery that RootBanner shrinks for the app content.
    final padding = MediaQuery.paddingOf(context);

    return Material(
      // Fills the whole box, so the colour paints up behind the status bar.
      color: resolved.background,
      child: InkWell(
        onTap: spec.onTap,
        child: Padding(
          padding: EdgeInsets.only(
            top: padding.top,
            left: padding.left + 16,
            right: padding.right + 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A banner has to survive a narrow box — a phone in a split view,
              // a tablet side panel — and the fixed decorations are what run out
              // of room first. Dropped in order of importance rather than
              // letting the Row overflow.
              const iconWidth = 18.0 + 8.0;
              const chevronWidth = 4.0 + 18.0;
              const minTextWidth = 24.0;
              final room = constraints.maxWidth;
              final showIcon = room >= iconWidth + minTextWidth;
              final showChevron =
                  spec.onTap != null &&
                  room >= iconWidth + chevronWidth + minTextWidth;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showIcon) ...[
                    Icon(
                      spec.icon ?? _defaultIcon(spec.severity),
                      size: 18,
                      color: resolved.foreground,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      spec.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: resolved.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: resolved.foreground,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
