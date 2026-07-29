# core_navigation

The app's navigation layer, and the only place a routing library appears. Today
that is [go_router](https://pub.dev/packages/go_router); nothing exported from
here names one of its types, and no package above this one depends on it.

Describe routes with this package's own types, declaring banners where the screen
is declared:

```dart
import 'package:core_navigation/core_navigation.dart';

final appRoutes = [
  AppShellRoute(
    // One widget from each package: the scope resolves, the host renders.
    builder: (context, child) => AppBannerScope(
      child: RootBanner(child: AppChrome(child: child)),
    ),
    children: [
      AppPageRoute(path: '/promo', banner: promoBanner, builder: ...),
      AppShellRoute(banner: betaBanner, children: [...]),
      AppTabsRoute(builder: ..., branches: [...]),
    ],
  ),
];

final router = AppRouter(routes: appRoutes);
MaterialApp.router(routerConfig: router.config);
```

| | |
|---|---|
| `AppPageRoute` | a screen at a path, with optional children. |
| `AppShellRoute` | chrome around everything nested inside it, on its own Navigator. |
| `AppTabsRoute` | one Navigator per branch, so each tab keeps its own stack. |
| `AppRouter` | builds the router. `config` is a Flutter `RouterConfig`. |
| `AppNavigator` | `go` / `push` / `pop` / `canPop`, and `locationOf` for reads. |
| `AppCanPopBuilder` | rebuilds with whether there is anything to go back to. |
| `AppBannerScope` | publishes the current screen's banners. No styling — that is `RootBanner`'s. |

Re-exports `banners`, so this is the only import an app needs.

## Why AppCanPopBuilder exists

"Can I go back?" is awkward in two ways, and both are navigation's problem rather
than the app's.

The answer is **not readable during a build**: it lives in the *innermost* shell's
live `NavigatorState`, which takes on its new page list later in the same build
pass, so a shell's builder sees the tree being replaced. Hence a post-frame sample.

And **nothing can be assumed to trigger that sample**. A shell's builder does
re-run on every navigation, so scheduling from `build` looks sufficient — it even
passes every test here. It breaks when the widget handed down is *identical* rather
than merely equal, as a `const` builder is: the element short-circuits, no build
happens, and the arrow silently never appears. Subscribing makes correctness
independent of who rebuilds the widget.

So it subscribes, samples after the frame, and rebuilds only when the answer
changes:

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

The subscription itself is handed to Flutter's `ListenableBuilder`, which already
holds a listenable and undoes it correctly. That is what removes the hand-written
`addListener` / `removeListener` pair: unsubscribing needs the same object that was
subscribed to, and an inherited lookup is illegal once `dispose` has started — but a
widget *parameter* is legal to read there, so `ListenableBuilder` can keep it
instead of us.

## Replacing go_router

Everything that knows about it is in `lib/src/`: `app_router.dart` (the mapping
and the router itself), `app_navigator.dart` (the actions), `banner_route.dart`
(route subclasses carrying banners), and `go_router_banner_source.dart` (reading
the matched chain). Rewrite those four against the new library and nothing above
changes.

`test/app_router_test.dart` imports the barrel and nothing else, so it is the spec
a replacement has to satisfy. `test/root_banner_test.dart` and `test/leak_test.dart`
reach into `src/` on purpose — they pin the go_router mapping specifically, and are
the tests a replacement would rewrite alongside the implementation.

Deliberately out of scope, since every router models them differently and this app
does not use them: typed route arguments, and redirects or guards.

See the [repository README](../../README.md) for the banner side.
