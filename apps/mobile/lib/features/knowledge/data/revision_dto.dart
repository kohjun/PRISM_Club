class RevisionDto {
  const RevisionDto({
    required this.id,
    required this.blockId,
    required this.version,
    required this.blockType,
    required this.title,
    required this.body,
    required this.source,
    required this.changedById,
    required this.changedByNickname,
    required this.changedAt,
    required this.contributionId,
  });

  final String id;
  final String blockId;
  final int version;
  final String blockType;
  final String title;
  final String body;

  /// SEED | CONTRIBUTION | ADMIN
  final String source;

  final String? changedById;
  final String? changedByNickname;
  final DateTime changedAt;
  final String? contributionId;

  factory RevisionDto.fromJson(Map<String, dynamic> json) {
    final changedBy = json['changed_by'];
    final String? authorId;
    final String? authorNick;
    if (changedBy is Map) {
      authorId = changedBy['id'] as String?;
      authorNick = changedBy['nickname'] as String?;
    } else {
      authorId = null;
      authorNick = null;
    }
    return RevisionDto(
      id: json['id'] as String,
      blockId: json['block_id'] as String,
      version: json['version'] as int,
      blockType: json['block_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      source: json['source'] as String? ?? 'CONTRIBUTION',
      changedById: authorId,
      changedByNickname: authorNick,
      changedAt: DateTime.parse(json['changed_at'] as String),
      contributionId: json['contribution_id'] as String?,
    );
  }
}

class RevisionListDto {
  const RevisionListDto({
    required this.items,
    required this.nextCursor,
  });

  final List<RevisionDto> items;
  final String? nextCursor;

  factory RevisionListDto.fromJson(Map<String, dynamic> json) =>
      RevisionListDto(
        items: (json['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(RevisionDto.fromJson)
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
      );
}
