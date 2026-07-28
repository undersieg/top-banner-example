import 'package:flutter/material.dart';

import 'banner_spec.dart';

/// Default banner renderer.
///
/// Contract for any replacement passed to `RootBanner.contentBuilder`: you are
/// handed a box of exactly `MediaQuery.paddingOf(context).top +
/// RootBanner.contentHeight` and tight constraints, so fill it. Paint your
/// background across the whole box (so colour runs up behind the status bar)
/// and inset your *content* by the top padding yourself, as this does.
class BannerView extends StatelessWidget {
  const BannerView({super.key, required this.spec});

  final BannerSpec spec;

  static IconData _defaultIcon(BannerSeverity severity) => switch (severity) {
    BannerSeverity.info => Icons.info_outline,
    BannerSeverity.success => Icons.check_circle_outline,
    BannerSeverity.warning => Icons.warning_amber_outlined,
    BannerSeverity.error => Icons.error_outline,
  };

  static ({Color background, Color foreground}) _colors(
    ColorScheme scheme,
    BannerSeverity severity,
  ) => switch (severity) {
    BannerSeverity.info => (
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
    ),
    BannerSeverity.success => (
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    ),
    BannerSeverity.warning => (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
    ),
    BannerSeverity.error => (
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colors(theme.colorScheme, spec.severity);
    // Read the *unadjusted* padding: this widget is rendered outside the
    // MediaQuery that RootBanner shrinks for the app content.
    final padding = MediaQuery.paddingOf(context);

    return Material(
      // Fills the whole box, so the colour paints up behind the status bar.
      color: colors.background,
      child: InkWell(
        onTap: spec.onTap,
        child: Padding(
          padding: EdgeInsets.only(
            top: padding.top,
            left: padding.left + 16,
            right: padding.right + 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                spec.icon ?? _defaultIcon(spec.severity),
                size: 18,
                color: colors.foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  spec.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (spec.onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: colors.foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
