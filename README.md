# top_banner

A banner strip above the whole app, declared on **routes** instead of published
from page state.

```
packages/banners/           everything about banners: the host, the spec, the
                            ordering, the styling. Flutter, and nothing else.
packages/core_navigation/   everything about routing, go_router included — and
                            the only place it appears. Depends on banners.
example/                    the demo app. Depends on core_navigation only, and
                            names no routing-library type.
```

The split is by concern, not by convenience: `banners` cannot render a route,
`core_navigation` cannot render a banner, and the app cannot see either library's
internals. go_router is an implementation detail of `core_navigation/lib/src/`:
replacing it means rewriting three files, with route declarations, navigation
calls, and banners untouched.

```dart
BannerRoute(
  path: '/promo',
  banner: BannerSpec(message: 'Special promo running!', priority: 10),
  builder: (context, state) => const PromoPage(),
)
```

That is the entire per-screen API. There is no `showBanner()` to pair with a
`hideBanner()`, no registration to unwind in `dispose`, and no window during a
route transition where the outgoing page's banner is still up.

## Why route markers

The banner for a screen is a property *of* that screen, so it is declared where
the screen is declared. The host reads the matched route chain on every
navigation and renders what it finds:

- **works at any shell depth** — a marker on a shell applies to everything
  nested below it, four levels down included, because depth is just a position
  in a flat list;
- **no lifecycle to get wrong** — nothing is pushed or popped, so a banner
  cannot outlive its screen;
- **deep links are already correct** on the first frame, with no animation.

## Wiring

Describe the routes, build a router, mount the pair:

```dart
import 'package:core_navigation/core_navigation.dart';

final appRoutes = [
  AppShellRoute(
    // 1. Mount the scope in the outermost shell, with the host inside it. The
    //    scope answers "which routes are matched" and the host renders it — one
    //    widget from each package. The scope finds the router from context, so
    //    nothing has to be handed to it.
    builder: (context, child) => AppBannerScope(
      child: RootBanner(child: AppChrome(child: child)),
    ),
    children: [
      // 2. Declare banners where the screen is declared.
      AppPageRoute(path: '/promo', banner: promoBanner, builder: ...),
      AppShellRoute(banner: betaBanner, children: [...]),
      AppTabsRoute(builder: ..., branches: [...]),
    ],
  ),
];

// 3. `config` is a Flutter RouterConfig, so this says nothing about which
//    router is underneath.
final router = AppRouter(routes: appRoutes);
MaterialApp.router(routerConfig: router.config);
```

Navigate through `AppNavigator`, which separates actions from reads:

```dart
AppNavigator.of(context).go('/promo');    // action, registers no dependency
AppNavigator.of(context).push('/promo');
AppNavigator.of(context).pop();
AppNavigator.of(context).canPop;
AppNavigator.locationOf(context);         // read, so the caller rebuilds on it
```

Conflating those two is how a nav bar ends up either stale or rebuilding the
world.

`canPop` is neither an action nor a plain read, so it has its own widget:

```dart
AppCanPopBuilder(
  builder: (context, canPop) => AppBar(
    automaticallyImplyLeading: false,
    leading: canPop
        ? BackButton(onPressed: () => AppNavigator.of(context).pop())
        : null,
  ),
)
```

The answer lives in the innermost shell's live `NavigatorState`, which only holds
the new page list *after* the frame — read during a build, it describes the tree
being replaced. And it has to be re-read on navigation without relying on being
rebuilt by it, since a `const` builder short-circuits the rebuild and would go
silently stale. `AppCanPopBuilder` owns both problems, and the subscription they
need, so a shell that wants a back arrow stays a `StatelessWidget`.

To sit above the root `Navigator` too — so root-navigator routes and
`useRootNavigator: true` dialogs cannot cover the banners — mount the pair in
`MaterialApp.router`'s `builder` and pass `router:` explicitly. Nothing is in
scope above the Router, so that is the one case where it has to be handed over.

`AppTabsRoute` gives each branch its own Navigator and its own stack. Declare a
tab's banner on the branch's **first route**: the container that holds every tab
is not a route in every routing library, so a banner there would not be portable.

## Stacking

Several markers in one chain — or several banners on one marker — stack. Order
is `priority` descending, then deepest marker first (a page's own banner sits
above its section's), then declaration order. Ties are resolved on an explicit
key, not on sort stability, which Dart does not provide.

`RootBannerStyle.maxVisible` caps the stack, keeping the highest priority ones.
Uncapped, the host still refuses to let the strip take more than half the
viewport — otherwise a long chain squeezes the app to zero height.

## Styling

Everything about appearance and timing is one value object, so a wrapper
forwards it whole rather than restating each parameter:

```dart
RootBanner(
  style: const RootBannerStyle(
    contentHeight: 52,
    maxVisible: 2,
    duration: Duration(milliseconds: 180),
    // Rebuild the app below only on stack changes rather than on every frame
    // of the transition.
    animateInsets: false,
  ),
  child: AppShell(child: child),
)
```

Styling lives on the host, in the banners package. The routing side has no
opinion about it and no parameter for it — a combined host had to accept a style
it never read and forward it, which is exactly the parameter that drifts.

Re-map severities without replacing the renderer:

```dart
RootBannerStyle(
  contentBuilder: (context, spec) =>
      BannerView(spec: spec, colors: myBrandColors),
)
```

Or replace it outright with `contentBuilder`. Your builder is handed a box of
exactly `MediaQuery.paddingOf(context).top + contentHeight` with tight
constraints: paint the background across all of it so the colour runs up behind
the status bar, and inset your content by the top padding yourself.

The strip consumes the status bar inset instead of doubling it — the app below
sees `padding.top`, `viewPadding.top`, and `size.height` reduced by exactly what
the strip covers, tracking the animation. `viewInsets` is left alone, so the
keyboard still resizes normally.

## Using another router

Two boundaries, enforced differently — worth knowing which is which:

- **`banners` cannot see go_router at all.** It lists Flutter and nothing else, so
  `package:go_router` does not resolve there: a hard `uri_does_not_exist`.
- **The app *could* see it, and is stopped by lint.** go_router reaches `example/`
  transitively through `core_navigation`, and Dart puts the whole transitive
  closure in the package config, so an import would otherwise resolve.
  `depend_on_referenced_packages` is promoted to `error` in
  `example/analysis_options.yaml`, so `flutter analyze` fails on it.

Both are also guarded at the pubspec level (`banner_boundary_test.dart`,
`navigation_boundary_test.dart`), since the way to defeat either is to add the
dependency rather than to sneak an import past it.

The seam is a plain `ValueListenable<List<BannerSpec>>`:

```dart
typedef BannerSource = ValueListenable<List<BannerSpec>>;
```

An adapter for a different router needs no base class from `banners` — it
implements `BannerMarker` on whatever describes a screen, flattens the current
chain outermost-first through `BannerStack.order`, and publishes the result via
`BannerSourceScope`. `packages/core_navigation/lib/src/` is ~40 lines of exactly
that for go_router; a second adapter sits beside it without either one knowing.

## Replacing the router

`core_navigation/lib/src/` is the only code that names go_router:

| | |
|---|---|
| `app_router.dart` | maps the `AppRoute` tree onto go_router's, and owns the `GoRouter`. |
| `app_navigator.dart` | `go` / `push` / `pop` / `canPop` / `locationOf` / `changes`, and `AppCanPopBuilder`. |
| `banner_route.dart` | `GoRoute` and `ShellRoute` subclasses carrying banners. |
| `go_router_banner_source.dart` | reads the matched chain on every navigation. |

Swapping routers means rewriting those against the new library. Route
declarations, navigation calls, banners, and the rest of the app do not change,
and `test/app_router_test.dart` — which imports the barrel and nothing else — is
the spec the replacement has to satisfy.

Two things are deliberately *not* in the model, because every router does them
differently and this app does not need them: typed route arguments, and redirects
or guards. Those are the places the abstraction would have to grow.

Pass a `BannerStackPolicy` to reorder, dedupe, or drop by depth; it receives the
grouped chain, since depth cannot be recovered once the groups are flattened.

## Layout

```
┌──────────────────────┐  ← status bar inset, painted by the top banner
│  banner 1            │
├──────────────────────┤
│  banner 2            │  contentHeight each, scaled by MediaQuery.textScaler
├──────────────────────┤
│                      │
│  your app            │  gets the remaining box, and a MediaQuery to match
│                      │
└──────────────────────┘
```

Growing reveals new banners below the ones already on screen, which hold
position. Shrinking clips the outgoing stack away and hands over once the strip
has arrived, so N→N-1 animates instead of snapping.

## Example

`example/` is a demo app with markers at every depth: a leaf marker, two banners
on one route, four levels of nested shells (one of them unmarked, to show it is
transparent), and a `StatefulShellRoute`.

```sh
cd example && flutter pub get && flutter run
```

## Tests

Three packages, three suites. There is no shared resolution, so each needs its
own `pub get`:

```sh
flutter pub get                                  # the root, for `flutter analyze`
for d in packages/banners packages/core_navigation example; do
  (cd $d && flutter pub get && flutter test)
done
```

`flutter analyze` from the root covers all of them.

Every suite runs with leak tracking on (`test/flutter_test_config.dart`), widened
past the default set of tracked types. It is installed there rather than from a
test's `main` because instrumentation wraps object *creation*: enabling it once
the binding is up finds nothing and passes vacuously.
