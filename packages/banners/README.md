# banners

Everything about banners: the host that renders them, the spec that describes
one, the ordering, and the styling. Depends on Flutter and nothing else —
deliberately, and the pubspec is guarded by `test/banner_boundary_test.dart`.

`RootBanner` renders whatever stack a `BannerSource` reports, and re-renders when
that source notifies:

```dart
typedef BannerSource = ValueListenable<List<BannerSpec>>;
```

That is the whole contract with the outside world. Filling it is a router's job,
so using this package needs an adapter — there is one for go_router in
[`../core_navigation`](../core_navigation), and an app should depend on that
rather than on this package directly.

| | |
|---|---|
| `RootBanner` | the host. Mount one, above the outermost `Navigator` you want banners over. |
| `RootBannerStyle` | height, cap, timing, renderer, `animateInsets`. All of it, in one value. |
| `BannerSpec` | message, severity, icon, tap, priority. |
| `BannerMarker` | implement on whatever describes a screen in your router. |
| `BannerStack` | ordering: priority, then depth, then declaration. Replaceable. |
| `BannerView` | the default renderer, with a re-mappable severity palette. |
| `BannerStripTransition` | the grow/shrink state machine, unit-testable on its own. |

See the [repository README](../../README.md) for the full picture.
