import 'package:core_navigation/core_navigation.dart';
import 'package:flutter/material.dart';

import 'demo_pages.dart';

void main() => runApp(const App());

/// Banners are declared on routes, so they are plain constants.
class Banners {
  const Banners._();

  static const promo = BannerSpec(
    message: 'Special promo running!',
    severity: BannerSeverity.warning,
    icon: Icons.celebration,
    priority: 10,
  );

  /// Declared on shell 2, so it covers every route in that section.
  static const betaSection = BannerSpec(
    message: 'Beta area — things may break',
    severity: BannerSeverity.info,
    icon: Icons.science,
  );

  /// Higher priority, so it stacks above [betaSection] on its own page.
  static const call = BannerSpec(
    message: 'Call in progress',
    severity: BannerSeverity.success,
    icon: Icons.call,
    priority: 20,
  );

  static const offline = BannerSpec(
    message: 'No connection',
    severity: BannerSeverity.error,
    icon: Icons.wifi_off,
    priority: 30,
  );

  /// Declared on shell 4, two levels below [betaSection].
  static const sandbox = BannerSpec(
    message: 'Sandbox — data is not real',
    severity: BannerSeverity.info,
    icon: Icons.inventory_2_outlined,
    priority: 5,
  );

  static const danger = BannerSpec(
    message: 'Destructive actions enabled',
    severity: BannerSeverity.error,
    icon: Icons.warning_amber,
    priority: 40,
  );

  static const inbox = BannerSpec(
    message: '3 unread messages',
    severity: BannerSeverity.info,
    icon: Icons.mark_email_unread_outlined,
  );
}

/// The whole app's navigation, and not one routing-library type in sight.
final List<AppRoute> appRoutes = [
  // Shell 1: app chrome. No banner of its own.
  AppShellRoute(
    // The only wiring point, and the layering in two lines: the scope answers
    // "which routes are matched" and the host renders it — one widget from each
    // package. The scope finds the router from context, so nothing is handed to
    // it.
    builder: (context, child) => AppBannerScope(
      child: RootBanner(child: AppShell(child: child)),
    ),
    children: [
      AppPageRoute(
        path: '/',
        builder: (context) => const DemoBody(
          title: 'Home',
          note: 'No banner declared on this route, so no banner.',
          links: [
            ('Push the promo page', '/promo'),
            ('Push the two-banner page', '/double'),
          ],
        ),
      ),
      AppPageRoute(
        path: '/plain',
        builder: (context) =>
            const DemoBody(title: 'Plain', note: 'Still no banner.'),
      ),

      // A banner on a leaf route.
      AppPageRoute(
        path: '/promo',
        banner: Banners.promo,
        builder: (context) => const DemoBody(
          title: 'Promo',
          note: '1 banner, declared by this route.',
        ),
      ),

      // Two banners declared by one route. They stack highest priority first,
      // so `offline` (30) sits above `promo` (10) regardless of list order.
      AppPageRoute(
        path: '/double',
        banners: [Banners.promo, Banners.offline],
        builder: (context) => const DemoBody(
          title: 'Two banners',
          note: '2 banners, both from this one route, ordered by priority.',
        ),
      ),

      // Shell 2: carries a banner, so it applies to everything nested below —
      // including routes inside shells 3 and 4.
      AppShellRoute(
        banner: Banners.betaSection,
        builder: (context, child) => LabeledShell(
          label: 'Shell 2 — beta (banner)',
          depth: 2,
          child: child,
        ),
        children: [
          AppPageRoute(
            path: '/beta',
            builder: (context) => const DemoBody(
              title: 'Beta home',
              note: '1 banner, inherited from shell 2.',
              links: [
                ('Push the call page', '/beta/call'),
                ('Push into shell 3', '/beta/tools'),
              ],
            ),
          ),
          AppPageRoute(
            path: '/beta/call',
            banner: Banners.call,
            builder: (context) => const DemoBody(
              title: 'Call',
              note: '2 banners: this route stacked above shell 2.',
            ),
          ),

          // Shell 3: no banner. Proves an undeclared shell in the middle of the
          // chain is simply transparent.
          AppShellRoute(
            builder: (context, child) => LabeledShell(
              label: 'Shell 3 — tools (no banner)',
              depth: 3,
              child: child,
            ),
            children: [
              AppPageRoute(
                path: '/beta/tools',
                builder: (context) => const DemoBody(
                  title: 'Tools',
                  note: 'Still 1 banner: shell 3 declares nothing.',
                  links: [('Push into shell 4', '/beta/tools/sandbox')],
                ),
              ),

              // Shell 4: declares one again, four levels deep.
              AppShellRoute(
                banner: Banners.sandbox,
                builder: (context, child) => LabeledShell(
                  label: 'Shell 4 — sandbox (banner)',
                  depth: 4,
                  child: child,
                ),
                children: [
                  AppPageRoute(
                    path: '/beta/tools/sandbox',
                    builder: (context) => const DemoBody(
                      title: 'Sandbox',
                      note: '2 banners, from shells 4 and 2.',
                      links: [
                        ('Push the danger page', '/beta/tools/sandbox/danger'),
                      ],
                    ),
                  ),
                  AppPageRoute(
                    path: '/beta/tools/sandbox/danger',
                    banner: Banners.danger,
                    builder: (context) => const DemoBody(
                      title: 'Danger',
                      note: '3 banners: this route, shell 4, and shell 2.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Tabs are also just another link in the chain. Banners go on a branch's
      // first route — see AppTabsRoute on why the container carries none.
      AppTabsRoute(
        builder: (context, tabs) => TabsShell(tabs: tabs),
        branches: [
          AppTabBranch(
            routes: [
              AppPageRoute(
                path: '/tabs/inbox',
                banner: Banners.inbox,
                builder: (context) => const DemoBody(
                  title: 'Inbox tab',
                  note: '1 banner, declared by this branch root.',
                ),
              ),
            ],
          ),
          AppTabBranch(
            routes: [
              AppPageRoute(
                path: '/tabs/profile',
                builder: (context) => const DemoBody(
                  title: 'Profile tab',
                  note: 'Nothing declared on this branch, so no banner.',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppRouter _router = AppRouter(routes: appRoutes);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Root banner',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    routerConfig: _router.config,
  );
}
