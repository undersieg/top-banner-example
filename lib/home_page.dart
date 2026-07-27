import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => context.go('/plain'),
            child: const Text('Plain page'),
          ),
          ElevatedButton(
            onPressed: () => context.go('/promo'),
            child: const Text('Promo page'),
          ),
        ],
      ),
    ),
  );
}
