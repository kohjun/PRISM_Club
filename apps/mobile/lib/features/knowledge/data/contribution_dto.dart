import '../../event_card/data/event_card_dto.dart';
import '../../reference/data/reference_dto.dart';

/// Status values returned by the server. String-typed for forward compatibility
/// — unknown values fall through to `pending` semantics in the UI.
class ContributionStatus {
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
  static const needsChanges = 'NEEDS_CHANGES';
  static const withdrawn = 'WITHDRAWN';
}

class ContributionAuthor {
  const ContributionAuthor({required this.id, required this.nickname});
  final String id;
  final String nickname;

  factory ContributionAuthor.fromJson(Map<String, dynamic> json) => ContributionAuthor(
        id: json['id'] as String,
        nickname: json['nickname'] as String? ?? '',
      );
}

class ContributionDto {
  const ContributionDto({
    required this.id,
    required this.topicHubId,
    required this.categorySlug,
    required this.contributor,
    required this.targetBlockId,
    required this.proposedBlockType,
    required this.proposedTitle,
    required this.status,
    required this.evidenceType,
    required this.hasEvidence,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final String topicHubId;
  final String categorySlug;
  final ContributionAuthor contributor;
  final String? targetBlockId;
  final String proposedBlockType;
  final String proposedTitle;
  final String status;
  final String? evidenceType;
  final bool hasEvidence;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  bool get isNewBlockProposal => targetBlockId == null;

  factory ContributionDto.fromJson(Map<String, dynamic> json) => ContributionDto(
        id: json['id'] as String,
        topicHubId: json['topic_hub_id'] as String,
        categorySlug: json['category_slug'] as String? ?? '',
        contributor: ContributionAuthor.fromJson(
            (json['contributor'] as Map).cast<String, dynamic>()),
        targetBlockId: json['target_block_id'] as String?,
        proposedBlockType: json['proposed_block_type'] as String,
        proposedTitle: json['proposed_title'] as String,
        status: json['status'] as String,
        evidenceType: json['evidence_type'] as String?,
        hasEvidence: json['has_evidence'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
      );
}

class ContributionCurrentBlock {
  const ContributionCurrentBlock({
    required this.id,
    required this.blockType,
    required this.title,
    required this.body,
  });
  final String id;
  final String blockType;
  final String title;
  final String body;

  factory ContributionCurrentBlock.fromJson(Map<String, dynamic> json) =>
      ContributionCurrentBlock(
        id: json['id'] as String,
        blockType: json['block_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
      );
}

class ContributionSnapshot {
  const ContributionSnapshot({
    required this.blockType,
    required this.title,
    required this.body,
  });
  final String blockType;
  final String title;
  final String body;

  factory ContributionSnapshot.fromJson(Map<String, dynamic> json) => ContributionSnapshot(
        blockType: json['block_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
      );
}

class ContributionDetailDto {
  const ContributionDetailDto({
    required this.summary,
    required this.proposedBody,
    required this.currentBlock,
    required this.evidence,
    required this.curatorNote,
    required this.resolverNickname,
    required this.snapshot,
  });

  final ContributionDto summary;
  final String proposedBody;
  final ContributionCurrentBlock? currentBlock;
  final Object? evidence; // EventCardDto or ReferenceDto or null
  final String? curatorNote;
  final String? resolverNickname;
  final ContributionSnapshot? snapshot;

  EventCardDto? get evidenceEvent =>
      evidence is EventCardDto ? evidence as EventCardDto : null;
  ReferenceDto? get evidenceReference =>
      evidence is ReferenceDto ? evidence as ReferenceDto : null;

  factory ContributionDetailDto.fromJson(Map<String, dynamic> json) {
    final summary = ContributionDto.fromJson(json);
    final currentBlockMap = json['current_block'] as Map?;
    final evidenceJson = json['evidence'];
    Object? evidence;
    if (summary.evidenceType == 'EVENT_CARD' && evidenceJson is Map) {
      evidence = EventCardDto.fromJson(evidenceJson.cast<String, dynamic>());
    } else if (summary.evidenceType == 'REFERENCE' && evidenceJson is Map) {
      evidence = ReferenceDto.fromJson(evidenceJson.cast<String, dynamic>());
    }
    final snapshotMap = json['snapshot'] as Map?;
    return ContributionDetailDto(
      summary: summary,
      proposedBody: json['proposed_body'] as String,
      currentBlock: currentBlockMap != null
          ? ContributionCurrentBlock.fromJson(currentBlockMap.cast<String, dynamic>())
          : null,
      evidence: evidence,
      curatorNote: json['curator_note'] as String?,
      resolverNickname: json['resolver_nickname'] as String?,
      snapshot: snapshotMap != null
          ? ContributionSnapshot.fromJson(snapshotMap.cast<String, dynamic>())
          : null,
    );
  }
}

class SubmitContributionRequest {
  const SubmitContributionRequest({
    this.targetBlockId,
    required this.proposedBlockType,
    required this.proposedTitle,
    required this.proposedBody,
    this.evidenceType,
    this.evidenceTargetId,
  });

  final String? targetBlockId;
  final String proposedBlockType;
  final String proposedTitle;
  final String proposedBody;
  final String? evidenceType;
  final String? evidenceTargetId;

  Map<String, dynamic> toJson() => {
        'target_block_id': ?targetBlockId,
        'proposed_block_type': proposedBlockType,
        'proposed_title': proposedTitle,
        'proposed_body': proposedBody,
        'evidence_type': ?evidenceType,
        'evidence_target_id': ?evidenceTargetId,
      };
}

class ResolveContributionRequest {
  const ResolveContributionRequest({required this.decision, this.note});
  final String decision; // 'APPROVE' | 'REJECT' | 'REQUEST_CHANGES'
  final String? note;

  Map<String, dynamic> toJson() => {
        'decision': decision,
        'note': ?note,
      };
}
