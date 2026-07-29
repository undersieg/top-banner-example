# Changelog

## 0.1.0

First extractable version. This package owns every banner concern — hosting,
description, ordering, styling — and knows nothing about routing. The go_router
adapter is a separate package; see `../core_navigation`.

- `BannerSpec` / `BannerMarker` / `BannerStack` — declare banners on anything
  that describes a screen, ordered by priority, then depth, then declaration.
- `RootBanner` — the host. Renders the stack, animates grow and shrink, consumes
  the status bar inset, and caps the strip at half the viewport.
- `RootBannerStyle` — appearance and timing as one value object, including
  `animateInsets` for opting out of per-frame rebuilds below.
- `BannerSource` (`ValueListenable<List<BannerSpec>>`) and `BannerSourceScope` —
  the routing-agnostic seam. `lib/src/banner` imports Flutter and nothing else.
- `BannerStackPolicy` — replaceable ordering, handed the grouped chain so depth
  is still available.
- `BannerView` — the default renderer, with a `BannerColorResolver` for
  re-mapping severities. `success` and `warning` use fixed hues rather than
  borrowing brand roles from the `ColorScheme`.
- Accessibility: the strip scales with `MediaQuery.textScaler` instead of
  clipping, and each banner is announced as a live region.
- `BannerStripTransition` — the collapse state machine, separated from the widget
  so it can be unit-tested directly.
- Both test suites run under leak tracking.
