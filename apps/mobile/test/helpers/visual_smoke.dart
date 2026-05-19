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
    // One final pump catches deferred layout errors that the body
    // itself didn't pump through (e.g. font fallback re-layout).
    await tester.pump();
  } finally {
    FlutterError.onError = original;
  }
  if (captured.isNotEmpty) {
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
}

bool _isOverflowError(FlutterErrorDetails details) {
  final s = details.exceptionAsString();
  return s.contains('A RenderFlex overflowed') ||
      s.contains('overflowed by') ||
      s.contains('BoxConstraints forces an infinite');
}
