import 'package:flutter/material.dart';

import 'banner_scope.dart';
import 'banner_spec.dart';

class BannerHost extends StatelessWidget {
  final Widget child;
  const BannerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final controller = BannerScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final spec = controller.current;
        return Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: spec == null
                  ? const SizedBox(
                      key: ValueKey('empty'),
                      width: double.infinity,
                      height: 0,
                    )
                  : _Banner(key: ValueKey(spec), spec: spec),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: spec != null,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  final BannerSpec spec;
  const _Banner({super.key, required this.spec});

  ({Color color, IconData icon}) _style(ColorScheme scheme) {
    if (spec.networkBanner == true) {
      return (color: scheme.errorContainer, icon: Icons.wifi_off);
    }
    if (spec.callBanner == true) {
      return (color: scheme.tertiaryContainer, icon: Icons.call);
    }
    if (spec.presents == true) {
      return (color: scheme.primaryContainer, icon: Icons.celebration);
    }
    return (color: scheme.surfaceContainerHighest, icon: Icons.info_outline);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _style(scheme);
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: style.color, // fills the full height, including status bar
      child: InkWell(
        onTap: spec.onTap,
        child: Padding(
          // top inset pushes content below the status bar,
          // but the Material color still paints up into it
          padding: EdgeInsets.only(
            top: topInset + 10,
            bottom: 10,
            left: 16,
            right: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(style.icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(spec.message)),
            ],
          ),
        ),
      ),
    );
  }
}
