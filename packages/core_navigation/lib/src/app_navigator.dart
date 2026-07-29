import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Navigation, without naming the router doing it.
///
/// Split deliberately into actions and reads:
///
/// - [of] hands back a navigator for *doing* things. It registers no dependency,
///   so calling it from a build method does not make that widget rebuild on every
///   navigation.
/// - [locationOf] is a *read*, and does register a dependency, so a widget that
///   highlights the current tab rebuilds when the location changes.
///
/// Conflating the two is how a nav bar ends up either stale or rebuilding the
/// world; keeping them apart makes which one you asked for obvious at the call
/// site.
///
/// [canPop] is neither, and needs [AppCanPopBuilder] — see there for why.
@immutable
final class AppNavigator {
  const AppNavigator._(this._router);

  /// The navigator for the enclosing router. For actions — see the class docs.
  static AppNavigator of(BuildContext context) =>
      AppNavigator._(GoRouter.of(context));

  /// Null above the Router, where no navigator is in scope yet.
  static AppNavigator? maybeOf(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    return router == null ? null : AppNavigator._(router);
  }

  /// The current location's path, as a dependency: the caller rebuilds when it
  /// changes.
  static String locationOf(BuildContext context) =>
      GoRouterState.of(context).uri.path;

  final GoRouter _router;

  /// Replaces the current location. Back does not return here.
  void go(String location) => _router.go(location);

  /// Pushes on top of the current location, so [pop] returns.
  void push(String location) => _router.push<void>(location);

  /// Pops the innermost thing that can pop, walking into nested shells.
  ///
  /// Throws if nothing can — gate on [canPop].
  void pop() => _router.pop();

  /// Whether [pop] would do anything.
  ///
  /// Reads the live `NavigatorState` of the innermost shell, which takes on a new
  /// page list *later* in the same build pass. Sample it after the frame, not
  /// during one, or it answers about the tree that was just replaced — which is
  /// what [AppCanPopBuilder] is for.
  bool get canPop => _router.canPop();

  /// Notifies after every navigation.
  ///
  /// For reacting to navigation without depending on being rebuilt by it. Prefer
  /// [locationOf] when a rebuild is all you want; reach for this when the thing
  /// you need to re-read is not in the widget tree — see [AppCanPopBuilder].
  Listenable get changes => _router.routerDelegate;

  @override
  bool operator ==(Object other) =>
      other is AppNavigator && other._router == _router;

  @override
  int get hashCode => _router.hashCode;
}

/// Rebuilds with whether there is anything to go back to.
///
/// This exists so app code does not have to. Asking "can I go back?" is awkward
/// in two ways, and both belong to navigation rather than to the widget that
/// wants a back arrow.
///
/// **The answer is not readable during a build.** It lives in the *innermost*
/// shell's live `NavigatorState`, which takes on its new page list later in the
/// same build pass. Read it from a shell's builder and it describes the tree
/// being replaced: measured, a push that makes `canPop` true still reads `false`
/// from the enclosing build. So it is sampled in a post-frame callback.
///
/// **Nothing can be assumed to trigger that sample.** A shell's builder does
/// re-run on every navigation, so scheduling the sample from `build` looks
/// sufficient — and passes every test in this repository. It breaks the moment
/// the widget handed down is *identical* rather than merely equal, as a `const`
/// builder is: the element short-circuits, no build happens, no sample is taken,
/// and the arrow silently never appears. Subscribing to navigation instead makes
/// correctness independent of who rebuilds this widget, which is the property
/// worth having in something every screen leans on.
///
/// So it subscribes, samples after the frame, and rebuilds only when the answer
/// actually changes.
///
/// ```dart
/// AppCanPopBuilder(
///   builder: (context, canPop) => AppBar(
///     automaticallyImplyLeading: false,
///     leading: canPop
///         ? BackButton(onPressed: () => AppNavigator.of(context).pop())
///         : null,
///   ),
/// )
/// ```
///
/// `automaticallyImplyLeading` is worth the explicit `false`: the shell's own
/// route is the only one on the root Navigator, so `AppBar` never finds anything
/// poppable there even when an inner shell has plenty.
class AppCanPopBuilder extends StatefulWidget {
  const AppCanPopBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool canPop) builder;

  @override
  State<AppCanPopBuilder> createState() => _AppCanPopBuilderState();
}

class _AppCanPopBuilderState extends State<AppCanPopBuilder> {
  bool _canPop = false;

  @override
  Widget build(BuildContext context) {
    final navigator = AppNavigator.of(context);
    // ListenableBuilder holds the subscription and undoes it, which is the one
    // job that forced this widget to keep a navigator of its own: unsubscribing
    // needs the same object that was subscribed to, and an inherited lookup is
    // illegal once `dispose` has started. As a widget *parameter* it is legal to
    // read there, so Flutter's own builder can do the bookkeeping.
    return ListenableBuilder(
      listenable: navigator.changes,
      builder: (context, _) {
        // Reached on every navigation, because the subscription above does not
        // care whether anything rebuilt this widget — see the class docs.
        //
        // Deferred, because the innermost NavigatorState has not taken its new
        // page list yet: reading canPop here still describes the tree being
        // replaced. Repeated schedules converge, since the second one finds the
        // value unchanged.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final canPop = navigator.canPop;
          if (canPop != _canPop) setState(() => _canPop = canPop);
        });
        return widget.builder(context, _canPop);
      },
    );
  }
}
