import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// No mixin → no banner.
class PlainPage extends StatelessWidget {
  const PlainPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Plain'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
      ),
    ),
    body: const Center(child: Text('No banner here')),
  );
}
