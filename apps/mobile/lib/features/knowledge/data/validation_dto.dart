import '../../../core/json_helpers.dart';

/// Response from `GET /v1/knowledge-blocks/:blockId/validation`.
///
/// The score is the deterministic composite (revisions × 2 + approvals
/// × 3 + avg_reputation × 0.5 + age_days × 0.1). Mobile shouldn't try
/// to recompute it; the badge maps the label string directly into
/// design tokens and the bottom sheet shows the signals back to the
/// user so the explanation lives next to the verdict.
class ValidationDto {
  const ValidationDto({
    required this.blockId,
    required this.score,
    required this.label,
    required this.signals,
    required this.computedAt,
  });

  final String blockId;
  final double score;
  final String label;
  final ValidationSignalsDto signals;
  final String computedAt;

  factory ValidationDto.fromJson(Map<String, dynamic> json) => ValidationDto(
        blockId: asString(json, 'block_id'),
        score: asDouble(json, 'score'),
        label: asString(json, 'label'),
        signals: ValidationSignalsDto.fromJson(
          asMap(json, 'signals') ?? const <String, dynamic>{},
        ),
        computedAt: asString(json, 'computed_at'),
      );
}

class ValidationSignalsDto {
  const ValidationSignalsDto({
    required this.revisions,
    required this.approvals,
    required this.avgReputation,
    required this.ageDays,
  });

  final int revisions;
  final int approvals;
  final double avgReputation;
  final int ageDays;

  factory ValidationSignalsDto.fromJson(Map<String, dynamic> json) =>
      ValidationSignalsDto(
        revisions: asInt(json, 'revisions'),
        approvals: asInt(json, 'approvals'),
        avgReputation: asDouble(json, 'avg_reputation'),
        ageDays: asInt(json, 'age_days'),
      );
}
