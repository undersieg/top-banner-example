import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'banner/banner.dart';
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

final List<RouteBase> appRoutes = [
  // Shell 1: app chrome. No marker.
  ShellRoute(
    builder: (context, state, child) => AppShell(child: child),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DemoBody(
          title: 'Home',
          note: 'No marker on this route, so no banner.',
          links: [
            ('Push the promo page', '/promo'),
            ('Push the two-banner page', '/double'),
          ],
        ),
      ),
      GoRoute(
        path: '/plain',
        builder: (context, state) =>
            const DemoBody(title: 'Plain', note: 'Still no banner.'),
      ),

      // Marker on a leaf route.
      BannerRoute(
        path: '/promo',
        banner: Banners.promo,
        builder: (context, state) => const DemoBody(
          title: 'Promo',
          note: '1 banner, declared by this route.',
        ),
      ),

      // Two banners declared by one route. They stack highest priority first,
      // so `offline` (30) sits above `promo` (10) regardless of list order.
      BannerRoute(
        path: '/double',
        banners: [Banners.promo, Banners.offline],
        builder: (context, state) => const DemoBody(
          title: 'Two banners',
          note: '2 banners, both from this one route, ordered by priority.',
        ),
      ),

      // Shell 2: marked, so it applies to everything nested below — including
      // routes inside shells 3 and 4.
      BannerShellRoute(
        banner: Banners.betaSection,
        builder: (context, state, child) => LabeledShell(
          label: 'Shell 2 — beta (marked)',
          depth: 2,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/beta',
            builder: (context, state) => const DemoBody(
              title: 'Beta home',
              note: '1 banner, inherited from shell 2.',
              links: [
                ('Push the call page', '/beta/call'),
                ('Push into shell 3', '/beta/tools'),
              ],
            ),
          ),
          BannerRoute(
            path: '/beta/call',
            banner: Banners.call,
            builder: (context, state) => const DemoBody(
              title: 'Call',
              note: '2 banners: this route stacked above shell 2.',
            ),
          ),

          // Shell 3: no marker. Proves an unmarked shell in the middle of the
          // chain is simply transparent.
          ShellRoute(
            builder: (context, state, child) => LabeledShell(
              label: 'Shell 3 — tools (no marker)',
              depth: 3,
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/beta/tools',
                builder: (context, state) => const DemoBody(
                  title: 'Tools',
                  note: 'Still 1 banner: shell 3 declares nothing.',
                  links: [('Push into shell 4', '/beta/tools/sandbox')],
                ),
              ),

              // Shell 4: marked again, four levels deep.
              BannerShellRoute(
                banner: Banners.sandbox,
                builder: (context, state, child) => LabeledShell(
                  label: 'Shell 4 — sandbox (marked)',
                  depth: 4,
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/beta/tools/sandbox',
                    builder: (context, state) => const DemoBody(
                      title: 'Sandbox',
                      note: '2 banners, from shells 4 and 2.',
                      links: [
                        ('Push the danger page', '/beta/tools/sandbox/danger'),
                      ],
                    ),
                  ),
                  BannerRoute(
                    path: '/beta/tools/sandbox/danger',
                    banner: Banners.danger,
                    builder: (context, state) => const DemoBody(
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

      // A StatefulShellRoute is also just another link in the chain. Markers go
      // on the branch's routes: StatefulShellBranch is not a RouteBase, so a
      // marker there would never be seen.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabsShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              BannerRoute(
                path: '/tabs/inbox',
                banner: Banners.inbox,
                builder: (context, state) => const DemoBody(
                  title: 'Inbox tab',
                  note: '1 banner, declared by this branch root.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tabs/profile',
                builder: (context, state) => const DemoBody(
                  title: 'Profile tab',
                  note: 'No marker on this branch, so no banner.',
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
  final GoRouter _router = GoRouter(routes: appRoutes);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Root banner',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    routerConfig: _router,
    // The one wiring point: above every shell, below Theme and MediaQuery.
    builder: (context, child) => RootBanner(router: _router, child: child!),
  );
}
