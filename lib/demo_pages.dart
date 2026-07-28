import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Outer shell chrome. The root banner renders *above* this AppBar, which is
/// the whole point of hosting it outside the router's shells.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = <(String label, String path, IconData icon)>[
    ('Home', '/', Icons.home_outlined),
    ('Plain', '/plain', Icons.article_outlined),
    ('Two', '/double', Icons.layers_outlined),
    ('Beta', '/beta', Icons.science_outlined),
    ('Tabs', '/tabs/inbox', Icons.tab_outlined),
  ];

  /// Explicit rather than `startsWith` over the list: '/' would prefix-match
  /// every location and pin the selection to Home.
  static int _indexFor(String location) {
    if (location.startsWith('/tabs')) return 4;
    if (location.startsWith('/beta')) return 3;
    if (location.startsWith('/double')) return 2;
    if (location.startsWith('/plain')) return 1;
    return 0;
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  GoRouter? _router;
  bool _canPop = false;
  bool _sampleScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (router == _router) return;
    _router?.routerDelegate.removeListener(_scheduleSample);
    _router = router;
    router.routerDelegate.addListener(_scheduleSample);
    _scheduleSample();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_scheduleSample);
    super.dispose();
  }

  /// `canPop()` reads the live [NavigatorState] of the innermost shell, and this
  /// widget is an *ancestor* of those navigators — they only take on the new
  /// page list later in the same build pass. Sampling after the frame is what
  /// makes the arrow agree with what is actually on the stack. This shell also
  /// does not rebuild on an imperative `push` (its own GoRouterState is
  /// unchanged), so the delegate listener is what wakes it up at all.
  void _scheduleSample() {
    if (_sampleScheduled) return;
    _sampleScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sampleScheduled = false;
      if (!mounted) return;
      final canPop = _router?.canPop() ?? false;
      if (canPop != _canPop) setState(() => _canPop = canPop);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // The shell's own route is the only one on the root Navigator, so
      // automaticallyImplyLeading never fires here even when an inner shell has
      // something to pop. GoRouter.pop walks down into the shell navigators and
      // pops the innermost poppable one, which is what this button needs; it
      // throws if nothing can pop, hence gating on [_canPop].
      automaticallyImplyLeading: false,
      leading: _canPop ? BackButton(onPressed: () => context.pop()) : null,
      title: const Text('Shell 1 — app chrome'),
    ),
    body: widget.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: AppShell._indexFor(GoRouterState.of(context).uri.path),
      onDestinationSelected: (i) => context.go(AppShell._destinations[i].$2),
      destinations: [
        for (final (label, _, icon) in AppShell._destinations)
          NavigationDestination(icon: Icon(icon), label: label),
      ],
    ),
  );
}

/// Chrome for a nested shell, indented by depth so every level in the chain is
/// visible on screen at once.
class LabeledShell extends StatelessWidget {
  const LabeledShell({
    super.key,
    required this.label,
    required this.depth,
    required this.child,
  });

  final String label;
  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.05 * depth),
            scheme.surfaceContainerHighest,
          ),
          padding: EdgeInsets.fromLTRB(8.0 * depth, 6, 12, 6),
          child: Row(
            children: [
              const Icon(Icons.subdirectory_arrow_right, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Chrome for a [StatefulShellRoute]: one Navigator per branch, so each tab
/// keeps its own stack.
class TabsShell extends StatelessWidget {
  const TabsShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _labels = ['Inbox', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(
                'Shell 2 — stateful',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 12),
              for (var i = 0; i < _labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_labels[i]),
                    selected: shell.currentIndex == i,
                    onSelected: (_) => shell.goBranch(i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: shell),
      ],
    );
  }
}

class DemoBody extends StatelessWidget {
  const DemoBody({
    super.key,
    required this.title,
    this.note,
    this.links = const <(String, String)>[],
  });

  final String title;
  final String? note;

  /// Navigated with `push`, so banners can be watched across push and pop.
  final List<(String label, String path)> links;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          for (final (label, path) in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: () => context.push(path),
                child: Text(label),
              ),
            ),
        ],
      ),
    ),
  );
}
