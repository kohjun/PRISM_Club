import '../../../core/json_helpers.dart';

/// Response from `GET /v1/profiles/:userId/curator-portfolio` (P6.10).
class CuratorPortfolioDto {
  const CuratorPortfolioDto({
    required this.userId,
    required this.isCurator,
    required this.reputation,
    required this.resolvedContributions,
    required this.sourceRules,
  });

  final String userId;
  final bool isCurator;
  final CuratorReputationDto? reputation;
  final List<ResolvedContributionDto> resolvedContributions;
  final List<SourceRuleDto> sourceRules;

  bool get isEmpty =>
      resolvedContributions.isEmpty &&
      sourceRules.isEmpty &&
      reputation == null;

  factory CuratorPortfolioDto.fromJson(Map<String, dynamic> json) =>
      CuratorPortfolioDto(
        userId: asString(json, 'user_id'),
        isCurator: asBool(json, 'is_curator'),
        reputation: asMap(json, 'reputation') == null
            ? null
            : CuratorReputationDto.fromJson(asMap(json, 'reputation')!),
        resolvedContributions: asObjectList(
            json, 'resolved_contributions', ResolvedContributionDto.fromJson),
        sourceRules: asObjectList(json, 'source_rules', SourceRuleDto.fromJson),
      );
}

class CuratorReputationDto {
  const CuratorReputationDto({
    required this.weightedScore,
    required this.approvedCount,
    required this.rejectedCount,
    required this.needsChangesCount,
    required this.withdrawnCount,
  });

  final double weightedScore;
  final int approvedCount;
  final int rejectedCount;
  final int needsChangesCount;
  final int withdrawnCount;

  factory CuratorReputationDto.fromJson(Map<String, dynamic> json) =>
      CuratorReputationDto(
        weightedScore: asDouble(json, 'weighted_score'),
        approvedCount: asInt(json, 'approved_count'),
        rejectedCount: asInt(json, 'rejected_count'),
        needsChangesCount: asInt(json, 'needs_changes_count'),
        withdrawnCount: asInt(json, 'withdrawn_count'),
      );
}

class ResolvedContributionDto {
  const ResolvedContributionDto({
    required this.id,
    required this.title,
    required this.blockType,
    required this.categorySlug,
    required this.resolvedAt,
  });

  final String id;
  final String title;
  final String blockType;
  final String categorySlug;
  final String resolvedAt;

  factory ResolvedContributionDto.fromJson(Map<String, dynamic> json) =>
      ResolvedContributionDto(
        id: asString(json, 'id'),
        title: asString(json, 'title'),
        blockType: asString(json, 'block_type'),
        categorySlug: asString(json, 'category_slug'),
        resolvedAt: asString(json, 'resolved_at'),
      );
}

class SourceRuleDto {
  const SourceRuleDto({
    required this.id,
    required this.domainPattern,
    required this.tier,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String domainPattern;
  final String tier;
  final String? note;
  final String createdAt;

  factory SourceRuleDto.fromJson(Map<String, dynamic> json) => SourceRuleDto(
        id: asString(json, 'id'),
        domainPattern: asString(json, 'domain_pattern'),
        tier: asString(json, 'tier'),
        note: asStringOrNull(json, 'note'),
        createdAt: asString(json, 'created_at'),
      );
}
