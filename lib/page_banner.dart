import 'package:flutter/material.dart';

import 'banner/banner_controller.dart';
import 'banner/banner_scope.dart';
import 'banner/banner_spec.dart';

mixin PageBanner<T extends StatefulWidget> on State<T> {
  /// Override to declare the banner for this page.
  BannerSpec buildBanner();

  BannerController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Located once dependencies are available; safe to call repeatedly.
    _controller = BannerScope.of(context);
    _controller!.publish(this, buildBanner());
  }

  /// Call when banner content should change at runtime.
  void refreshBanner() => _controller?.publish(this, buildBanner());

  @override
  void dispose() {
    _controller?.retract(this);
    super.dispose();
  }
}
