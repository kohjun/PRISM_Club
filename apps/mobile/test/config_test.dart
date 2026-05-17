import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('web with no override returns localhost:3000/v1', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: '',
          isWeb: true,
          isAndroid: false,
        ),
        'http://localhost:3000/v1',
      );
    });

    test('Android emulator with no override returns 10.0.2.2:3000/v1', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: '',
          isWeb: false,
          isAndroid: true,
        ),
        'http://10.0.2.2:3000/v1',
      );
    });

    test('iOS Simulator / desktop with no override falls back to localhost', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: '',
          isWeb: false,
          isAndroid: false,
        ),
        'http://localhost:3000/v1',
      );
    });

    test('dart-define override always wins on web', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: 'https://api.staging.example.com/v1',
          isWeb: true,
          isAndroid: false,
        ),
        'https://api.staging.example.com/v1',
      );
    });

    test('dart-define override always wins on Android emulator', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: 'http://192.168.1.42:3000/v1',
          isWeb: false,
          isAndroid: true,
        ),
        'http://192.168.1.42:3000/v1',
      );
    });

    test('override trailing slash is stripped', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: 'https://api.example.com/v1/',
          isWeb: false,
          isAndroid: false,
        ),
        'https://api.example.com/v1',
      );
    });

    test('override multiple trailing slashes are stripped', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: 'https://api.example.com/v1////',
          isWeb: false,
          isAndroid: false,
        ),
        'https://api.example.com/v1',
      );
    });

    test('whitespace-only override is treated as empty', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: '   ',
          isWeb: false,
          isAndroid: true,
        ),
        'http://10.0.2.2:3000/v1',
      );
    });

    test('override with surrounding whitespace is trimmed', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: '  https://api.example.com/v1  ',
          isWeb: false,
          isAndroid: false,
        ),
        'https://api.example.com/v1',
      );
    });

    test('production-shaped override survives intact', () {
      expect(
        resolveApiBaseUrl(
          compileTimeOverride: 'https://api.club.prism.app/v1',
          isWeb: false,
          isAndroid: false,
        ),
        'https://api.club.prism.app/v1',
      );
    });

    test('apiBaseUrl property is non-empty on the current host', () {
      // The actual platform-resolved value depends on where the test
      // suite is running, so we only assert it has a sane shape rather
      // than a specific value.
      expect(apiBaseUrl, isNotEmpty);
      expect(apiBaseUrl, startsWith('http'));
    });
  });
}
