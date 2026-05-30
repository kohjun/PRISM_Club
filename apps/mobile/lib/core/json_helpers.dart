/// PR-C1 — shared JSON parsing helpers for DTO `fromJson` factories.
///
/// Before this, DTOs hand-rolled three divergent casting idioms:
///   - `(json['x'] as List?) ?? const []` + `.whereType<Map>()...`
///   - `(json['x'] as Map?)?.cast<String, dynamic>()`
///   - `json['x'] as String? ?? ''` / `(json['x'] as num?)?.toInt() ?? 0`
///
/// These helpers collapse the safe, mechanical cases into one place
/// with IDENTICAL null/default semantics to the inline code they
/// replace (pinned by test/dto_parsing_test.dart). They are
/// intentionally dumb — DTOs with custom branching (PostAttachmentDto,
/// ContributionDetailDto, RecruitmentFieldsDto capacity coercion) keep
/// their bespoke logic.
library;

/// Scalar string with a fallback. Mirrors `json[key] as String? ?? fallback`.
String asString(Map<String, dynamic> json, String key, {String fallback = ''}) =>
    json[key] as String? ?? fallback;

/// Nullable string. Mirrors `json[key] as String?`.
String? asStringOrNull(Map<String, dynamic> json, String key) =>
    json[key] as String?;

/// Int with a fallback, tolerant of `num` (e.g. a JSON `3.0`). Mirrors
/// `(json[key] as num?)?.toInt() ?? fallback`.
int asInt(Map<String, dynamic> json, String key, {int fallback = 0}) =>
    (json[key] as num?)?.toInt() ?? fallback;

/// Double with a fallback, tolerant of integer JSON. Mirrors
/// `(json[key] as num?)?.toDouble() ?? fallback`.
double asDouble(Map<String, dynamic> json, String key, {double fallback = 0}) =>
    (json[key] as num?)?.toDouble() ?? fallback;

/// Bool with a fallback. Mirrors `json[key] as bool? ?? fallback`.
bool asBool(Map<String, dynamic> json, String key, {bool fallback = false}) =>
    json[key] as bool? ?? fallback;

/// Nested object as `Map<String, dynamic>?`. Mirrors
/// `(json[key] as Map?)?.cast<String, dynamic>()`. Returns null when
/// absent or not a map.
Map<String, dynamic>? asMap(Map<String, dynamic> json, String key) {
  final v = json[key];
  return v is Map ? v.cast<String, dynamic>() : null;
}

/// List of typed objects. Mirrors the canonical
/// "list-or-empty, keep the maps, map each through fromJson, freeze"
/// idiom that ~20 DTOs hand-rolled.
List<T> asObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final raw = json[key] as List?;
  if (raw == null) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

/// List of strings — list-or-empty, keep only the string elements,
/// freeze. Mirrors the string-list idiom DTOs hand-rolled.
List<String> asStringList(Map<String, dynamic> json, String key) {
  final raw = json[key] as List?;
  if (raw == null) return const [];
  return raw.whereType<String>().toList(growable: false);
}

/// Nullable DateTime. Mirrors `raw != null ? DateTime.parse(raw) : null`
/// for an ISO-8601 string field.
DateTime? asDateTimeOrNull(Map<String, dynamic> json, String key) {
  final raw = json[key] as String?;
  return raw != null ? DateTime.parse(raw) : null;
}
