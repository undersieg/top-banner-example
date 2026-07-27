import 'package:flutter/foundation.dart';

@immutable
class BannerSpec {
  final String message;
  final bool? networkBanner;
  final bool? callBanner;
  final bool? presents;
  final VoidCallback? onTap;
  final int priority; // higher wins when multiple are active

  const BannerSpec({
    required this.message,
    this.networkBanner = false,
    this.callBanner = false,
    this.presents = false,
    this.onTap,
    this.priority = 0,
  });
}
