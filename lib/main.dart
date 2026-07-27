import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:top_banner_example/plain_page.dart';
import 'package:top_banner_example/promo_page.dart';

import 'banner/banner_controller.dart';
import 'banner/banner_host.dart';
import 'banner/banner_scope.dart';
import 'home_page.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _bannerController = BannerController();
  late final GoRouter _router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => BannerHost(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomePage()),
          GoRoute(path: '/plain', builder: (c, s) => const PlainPage()),
          GoRoute(path: '/promo', builder: (c, s) => const PromoPage()),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scope must wrap the router so every route can locate the controller.
    return BannerScope(
      controller: _bannerController,
      child: MaterialApp.router(routerConfig: _router),
    );
  }
}
