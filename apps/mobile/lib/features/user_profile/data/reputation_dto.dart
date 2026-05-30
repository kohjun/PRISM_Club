import '../../../core/json_helpers.dart';

class ReputationDto {
  const ReputationDto({
    required this.userId,
    required this.approvedCount,
    required this.rejectedCount,
    required this.needsChangesCount,
    required this.withdrawnCount,
    required this.weightedScore,
    required this.lastResolvedAt,
  });

  final String userId;
  final int approvedCount;
  final int rejectedCount;
  final int needsChangesCount;
  final int withdrawnCount;
  final double weightedScore;
  final DateTime? lastResolvedAt;

  bool get hasActivity =>
      approvedCount > 0 ||
      rejectedCount > 0 ||
      needsChangesCount > 0 ||
      withdrawnCount > 0;

  factory ReputationDto.fromJson(Map<String, dynamic> json) => ReputationDto(
        userId: json['user_id'] as String,
        approvedCount: asInt(json, 'approved_count'),
        rejectedCount: asInt(json, 'rejected_count'),
        needsChangesCount: asInt(json, 'needs_changes_count'),
        withdrawnCount: asInt(json, 'withdrawn_count'),
        weightedScore: asDouble(json, 'weighted_score'),
        lastResolvedAt: asDateTimeOrNull(json, 'last_resolved_at'),
      );
}
