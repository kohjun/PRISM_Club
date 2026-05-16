import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class PrismClubApp extends ConsumerWidget {
  const PrismClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PRISM Club',
      theme: buildPrismTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
