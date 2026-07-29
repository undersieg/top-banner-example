# Changelog

## 0.1.0

The app's navigation layer. go_router is an implementation detail of `lib/src/`:
nothing exported names one of its types, so replacing it does not reach the app.

- `AppRoute` / `AppPageRoute` / `AppShellRoute` / `AppTabsRoute` / `AppTabBranch`
  — a router-agnostic description of the route tree, with banners declared where
  the screen is declared. `sealed`, so the mapping onto the real router is
  exhaustive by the compiler.
- `AppRouter` — builds the router from that tree. `config` is a Flutter
  `RouterConfig`, so handing it to `MaterialApp.router` says nothing about which
  library is underneath. A node that declares no banner maps to a plain route
  rather than to a marker with an empty list, so nesting does not fill the chain
  with empty groups.
- `AppNavigator` — `go`, `push`, `pop`, `canPop`, `changes`, and `locationOf`.
  Actions and reads are separate: only the read registers a dependency.
- `AppCanPopBuilder` — rebuilds with whether anything can be popped, sampling
  after the frame and holding the navigation subscription so app code does not
  have to. Without it, every shell that wants a back arrow reimplements the same
  three subtleties.
- `AppTabs` — what a tab shell is handed: the views, the current index, and how to
  switch.
- `AppBannerScope` — owns the banner source's lifetime and publishes it.
  Deliberately does not mount the host or accept a style: rendering and styling
  belong to `RootBanner`, in the banners package. Wire them as
  `AppBannerScope(child: RootBanner(child: ...))`.
- Internal to `lib/src/`, and the only code naming go_router: `BannerRoute`,
  `BannerShellRoute`, `GoRouterBannerSource`.
