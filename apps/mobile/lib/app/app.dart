import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/data/fcm_sync.dart';
import 'router.dart';
import 'theme.dart';

class PrismClubApp extends ConsumerWidget {
  const PrismClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activates the device-token register/revoke + onTokenRefresh +
    // onNotificationTap wiring. Provider returns void; the watch just
    // mounts it.
    ref.watch(fcmSyncProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PRISM Club',
      theme: buildPrismTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
