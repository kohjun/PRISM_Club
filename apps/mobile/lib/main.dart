import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/observability/crashlytics_bootstrap.dart';

Future<void> main() async {
  // `runZonedGuarded` catches synchronous + asynchronous errors that
  // Flutter's own handlers miss (zone-spawned futures, isolate startup).
  // Crashlytics needs the binding initialized before the first frame so
  // we await `ensureInitialized` before installing the error handlers.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await CrashlyticsBootstrap.initialize();
    runApp(const ProviderScope(child: PrismClubApp()));
  }, (error, stack) {
    // Final safety net — anything thrown outside Flutter's own zones
    // lands here.
    debugPrint('uncaught zone error: $error');
  });
}
