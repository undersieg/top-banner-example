import 'package:flutter/material.dart';

import 'banner_controller.dart';

class BannerScope extends InheritedNotifier<BannerController> {
  const BannerScope({
    super.key,
    required BannerController controller,
    required super.child,
  }) : super(notifier: controller);

  static BannerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BannerScope>();
    assert(scope != null, 'No BannerScope found in widget tree');
    return scope!.notifier!;
  }
}
