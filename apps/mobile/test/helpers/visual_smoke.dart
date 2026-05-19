import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two viewport sizes the smoke tests sweep:
///
///   * 360×800 — narrow Android (e.g. Pixel 4a, most low/mid Galaxy).
///   * 430×932 — wide modern phone (iPhone 16 Pro / Pro Max).
///
/// If a screen overflows on either, the test fails. We deliberately do
/// not include tablet sizes — the app is phone-first today.
const Size kSmokeNarrow = Size(360, 800);
const Size kSmokeWide = Size(430, 932);
const List<Size> kSmokeViewports = <Size>[kSmokeNarrow, kSmokeWide];

/// Sets [tester.view] to [size] in logical pixels with
/// `devicePixelRatio: 1`, and registers a tear-down to restore it. Call
/// this BEFORE `tester.pumpWidget` so the first frame is laid out at
/// the smoke size — `flutter_test`'s default is 800×600, which masks
/// the overflows we're trying to catch.
void setSmokeViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Runs [body], capturing any RenderFlex / box-constraint overflow
/// errors emitted via `FlutterError.onError`. Fails the surrounding
/// test if any are captured, with the full overflow text in the
/// failure message.
///
/// `FlutterError.onError` is always restored afterwards — even on
/// `body` failure — so a thrown exception in one test doesn't leak the
/// hook into the next.
///
/// Why this and not `tester.takeException()`: layout overflow errors
/// are routed through `FlutterError.reportError`, which by default
/// dumps to the console but does NOT register as a takeable exception.
/// The hook is the only way to make them assertable.
Future<void> expectNoOverflow(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final captured = await _runWithOverflowGuard(() async {
    await body();
    // One final pump catches deferred layout errors that the body
    // itself didn't pump through (e.g. font fallback re-layout).
    await tester.pump();
  });
  _failIfAny(captured);
}

/// Same overflow contract as [expectNoOverflow], but additionally
/// scrolls the screen end-to-end after [body] has mounted it. Catches
/// overflow errors in lazy regions of the tree — `CustomScrollView`
/// slivers, off-screen `ListView` items — that the simpler helper
/// never builds because they're outside the initial 800dp viewport.
///
/// Strategy: find the primary `Scrollable`, drag downward [passes]
/// times by [delta] logical pixels (pumping each frame so layout
/// errors surface), then drag back up by the same amount. Each drag
/// triggers a sliver build for the new visible region; pumps surface
/// any layout exceptions through `FlutterError.onError`.
///
/// Defaults ([passes] = 8, [delta] = 600) cover ~4800dp of scrollable
/// content twice — enough for every screen in the app today. Bump
/// `passes` for taller pages if needed.
Future<void> expectNoOverflowWhileScrolling(
  WidgetTester tester,
  Future<void> Function() body, {
  int passes = 8,
  double delta = 600.0,
}) async {
  final captured = await _runWithOverflowGuard(() async {
    await body();
    await tester.pump();

    final scrollable = find.byType(Scrollable);
    // Some test trees mount no Scrollable (error / loading states with
    // a centered ErrorView). Treat that as "nothing to scroll" — the
    // outer expectNoOverflow already pumped twice; we're done.
    if (scrollable.evaluate().isEmpty) return;
    final target = scrollable.first;

    for (var i = 0; i < passes; i++) {
      await tester.drag(target, Offset(0, -delta));
      await tester.pump();
    }
    for (var i = 0; i < passes; i++) {
      await tester.drag(target, Offset(0, delta));
      await tester.pump();
    }
    await tester.pump();
  });
  _failIfAny(captured);
}

Future<List<FlutterErrorDetails>> _runWithOverflowGuard(
  Future<void> Function() body,
) async {
  final captured = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isOverflowError(details)) {
      captured.add(details);
      return;
    }
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
  return captured;
}

void _failIfAny(List<FlutterErrorDetails> captured) {
  if (captured.isEmpty) return;
  final report = StringBuffer();
  report.writeln('Detected ${captured.length} overflow error(s):');
  for (var i = 0; i < captured.length; i++) {
    final d = captured[i];
    report.writeln('--- [$i] ${d.exceptionAsString()}');
    // d.context is a DiagnosticsNode that names the failing tree spot
    // — useful for tracking down which Column/Row in which screen.
    if (d.context != null) report.writeln('    context: ${d.context}');
    if (d.library != null) report.writeln('    library: ${d.library}');
  }
  fail(report.toString());
}

bool _isOverflowError(FlutterErrorDetails details) {
  final s = details.exceptionAsString();
  return s.contains('A RenderFlex overflowed') ||
      s.contains('overflowed by') ||
      s.contains('BoxConstraints forces an infinite');
}
