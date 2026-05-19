import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/safe_route.dart';

void main() {
  group('isSafeInternalRoute', () {
    test('accepts simple internal paths', () {
      expect(isSafeInternalRoute('/home'), isTrue);
      expect(isSafeInternalRoute('/me/contributions'), isTrue);
      expect(isSafeInternalRoute('/users/abc-123'), isTrue);
      expect(isSafeInternalRoute('/spaces/community/categories'), isTrue);
    });

    test('accepts paths with query strings', () {
      expect(isSafeInternalRoute('/search?q=hello'), isTrue);
      expect(isSafeInternalRoute('/search?q=hello&categorySlug=foo'), isTrue);
      expect(isSafeInternalRoute('/categories/x?spaceSlug=y'), isTrue);
    });

    test('rejects null and empty', () {
      expect(isSafeInternalRoute(null), isFalse);
      expect(isSafeInternalRoute(''), isFalse);
    });

    test('rejects paths without leading slash', () {
      expect(isSafeInternalRoute('home'), isFalse);
      expect(isSafeInternalRoute('users/123'), isFalse);
    });

    test('rejects protocol-relative URLs', () {
      // `//example.com/path` is fetched by browsers using the current
      // page's protocol — would be a real open-redirect on Flutter web.
      expect(isSafeInternalRoute('//example.com'), isFalse);
      expect(isSafeInternalRoute('//example.com/path'), isFalse);
    });

    test('rejects external URLs that start with a scheme', () {
      expect(isSafeInternalRoute('https://example.com'), isFalse);
      expect(isSafeInternalRoute('http://example.com'), isFalse);
      expect(isSafeInternalRoute('javascript:alert(1)'), isFalse);
    });

    test('rejects whitespace + control characters', () {
      expect(isSafeInternalRoute('/foo bar'), isFalse);
      expect(isSafeInternalRoute('/foo\nbar'), isFalse);
      expect(isSafeInternalRoute('/foo\tbar'), isFalse);
      expect(isSafeInternalRoute('/foo\rbar'), isFalse);
    });

    test('rejects unreasonably long inputs', () {
      // Real routes are tens of characters; cap is a sanity guard
      // against pathological deep-link payloads.
      final long = '/${'a' * 300}';
      expect(isSafeInternalRoute(long), isFalse);
    });

    test('accepts the routes the app actually constructs', () {
      // Mirrors the callsites in this commit so a future rename here
      // catches the corresponding test.
      expect(isSafeInternalRoute('/home'), isTrue);
      expect(isSafeInternalRoute('/me/contributions'), isTrue);
      expect(isSafeInternalRoute('/users/some-uuid-here'), isTrue);
      expect(isSafeInternalRoute('/search?q=love'), isTrue);
    });
  });
}
