import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:top_banner_example/page_banner.dart';

import 'banner/banner_spec.dart';

class PromoPage extends StatefulWidget {
  const PromoPage({super.key});
  @override
  State<PromoPage> createState() => _PromoPageState();
}

class _PromoPageState extends State<PromoPage> with PageBanner {
  @override
  BannerSpec buildBanner() => const BannerSpec(
    message: 'Special promo running!',
    networkBanner: true,
    callBanner: true,
    priority: 10,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Promo'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/'),
      ),
    ),
    body: const Center(child: Text('Promo content')),
  );
}
