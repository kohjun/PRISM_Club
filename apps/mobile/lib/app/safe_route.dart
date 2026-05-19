/// Returns true if [path] is safe to feed into `context.go(...)` as an
/// internal app route. Used by screens that accept a `returnTo=` query
/// parameter to validate the value before navigating — prevents
/// open-redirect-style behavior if the query is ever attacker-controlled
/// (e.g. surfaced through a deep link).
///
/// Rules:
///   - non-null, non-empty
///   - length capped (sanity bound; we have no internal routes longer)
///   - starts with a single `/`
///   - rejects `//host/...` (protocol-relative URLs Flutter web could follow)
///   - rejects whitespace / control characters in the path
///
/// This is intentionally a small allow-list, not a parser. Anything that
/// matches looks like a normal internal route (`/home`,
/// `/search?q=hello`, `/users/123`); anything that doesn't is dropped on
/// the floor and the caller falls back to its default.
bool isSafeInternalRoute(String? path) {
  if (path == null) return false;
  if (path.isEmpty || path.length > 256) return false;
  if (!path.startsWith('/')) return false;
  if (path.startsWith('//')) return false;
  if (path.contains('\n') || path.contains('\r') || path.contains('\t')) {
    return false;
  }
  if (path.contains(' ')) return false;
  return true;
}
