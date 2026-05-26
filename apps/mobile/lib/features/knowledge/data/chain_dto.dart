/// Response from `GET /v1/knowledge-blocks/:blockId/chain`.
///
/// Person-centric timeline complementing the existing
/// `block_revision_history_screen` (which is version-centric). Each
/// entry's `roleInChain` maps to the underlying revision row's source
/// (SEED / CONTRIBUTION / ADMIN) so the badge on the timeline can
/// reuse the same style tokens that `block_revision_history_screen`
/// already uses for revision sources.
class ChainDto {
  const ChainDto({required this.blockId, required this.items});

  final String blockId;
  final List<ChainEntryDto> items;

  factory ChainDto.fromJson(Map<String, dynamic> json) => ChainDto(
        blockId: json['block_id'] as String? ?? '',
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChainEntryDto.fromJson)
            .toList(growable: false),
      );
}

class ChainEntryDto {
  const ChainEntryDto({
    required this.userId,
    required this.nickname,
    required this.roleInChain,
    required this.actedAt,
    required this.revisionVersion,
    required this.contributionId,
  });

  final String? userId;
  final String? nickname;
  final String roleInChain;
  final String actedAt;
  final int revisionVersion;
  final String? contributionId;

  factory ChainEntryDto.fromJson(Map<String, dynamic> json) => ChainEntryDto(
        userId: json['user_id'] as String?,
        nickname: json['nickname'] as String?,
        roleInChain: json['role_in_chain'] as String? ?? 'SEED',
        actedAt: json['acted_at'] as String? ?? '',
        revisionVersion: (json['revision_version'] as num?)?.toInt() ?? 0,
        contributionId: json['contribution_id'] as String?,
      );
}
