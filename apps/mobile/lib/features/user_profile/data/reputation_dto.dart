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
        approvedCount: json['approved_count'] as int? ?? 0,
        rejectedCount: json['rejected_count'] as int? ?? 0,
        needsChangesCount: json['needs_changes_count'] as int? ?? 0,
        withdrawnCount: json['withdrawn_count'] as int? ?? 0,
        weightedScore: (json['weighted_score'] as num? ?? 0).toDouble(),
        lastResolvedAt: json['last_resolved_at'] != null
            ? DateTime.parse(json['last_resolved_at'] as String)
            : null,
      );
}
