import '../../event_card/data/event_card_dto.dart';
import '../../media/data/media_dto.dart';
import '../../reference/data/reference_dto.dart';
import 'recruitment_fields_dto.dart';

class PostAuthorDto {
  const PostAuthorDto({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
  });
  final String id;
  final String nickname;
  final String? avatarUrl;

  factory PostAuthorDto.fromJson(Map<String, dynamic> json) => PostAuthorDto(
        id: json['id'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class PostAttachmentDto {
  const PostAttachmentDto({
    required this.id,
    required this.attachmentType,
    required this.target,
    required this.sortOrder,
  });

  final String id;
  final String attachmentType; // EVENT_CARD | REFERENCE
  final Object target;
  final int sortOrder;

  EventCardDto? get asEventCard =>
      target is EventCardDto ? target as EventCardDto : null;
  ReferenceDto? get asReference =>
      target is ReferenceDto ? target as ReferenceDto : null;
  MediaAssetDto? get asImage =>
      target is MediaAssetDto ? target as MediaAssetDto : null;

  factory PostAttachmentDto.fromJson(Map<String, dynamic> json) {
    final type = json['attachment_type'] as String;
    final targetMap = (json['target'] as Map).cast<String, dynamic>();
    final Object target = type == 'EVENT_CARD'
        ? EventCardDto.fromJson(targetMap)
        : type == 'IMAGE'
            ? MediaAssetDto.fromJson(targetMap)
            : ReferenceDto.fromJson(targetMap);
    return PostAttachmentDto(
      id: json['id'] as String,
      attachmentType: type,
      target: target,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class QuotedPostRefDto {
  const QuotedPostRefDto({
    required this.id,
    required this.bodyPreview,
    required this.authorNickname,
    required this.roomSlug,
    required this.available,
  });

  final String id;
  final String bodyPreview;
  final String authorNickname;
  final String roomSlug;
  final bool available;

  factory QuotedPostRefDto.fromJson(Map<String, dynamic> json) =>
      QuotedPostRefDto(
        id: json['id'] as String? ?? '',
        bodyPreview: json['body_preview'] as String? ?? '',
        authorNickname: json['author_nickname'] as String? ?? '',
        roomSlug: json['room_slug'] as String? ?? '',
        available: json['available'] as bool? ?? true,
      );
}

/// P6.5 poll sidecar attached to a post.
class PollOptionDto {
  const PollOptionDto({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.voteCount,
  });
  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;

  factory PollOptionDto.fromJson(Map<String, dynamic> json) => PollOptionDto(
        id: json['id'] as String,
        label: json['label'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      );
}

class PollDto {
  const PollDto({
    required this.id,
    required this.question,
    required this.expiresAt,
    required this.allowMultiple,
    required this.status,
    required this.options,
    required this.totalVotes,
    required this.myVoteOptionIds,
  });
  final String id;
  final String question;
  final DateTime? expiresAt;
  final bool allowMultiple;
  final String status; // OPEN | CLOSED
  final List<PollOptionDto> options;
  final int totalVotes;
  final List<String> myVoteOptionIds;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isOpen => status == 'OPEN' && !isExpired;
  bool hasVotedFor(String optionId) => myVoteOptionIds.contains(optionId);

  factory PollDto.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    return PollDto(
      id: json['id'] as String,
      question: json['question'] as String,
      expiresAt: expiresRaw != null ? DateTime.parse(expiresRaw) : null,
      allowMultiple: json['allow_multiple'] as bool? ?? false,
      status: json['status'] as String? ?? 'OPEN',
      options: ((json['options'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PollOptionDto.fromJson)
          .toList(growable: false),
      totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
      myVoteOptionIds:
          ((json['my_vote_option_ids'] as List<dynamic>?) ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class PostDto {
  const PostDto({
    required this.id,
    required this.roomId,
    required this.roomSlug,
    required this.roomName,
    required this.author,
    required this.body,
    required this.status,
    required this.postType,
    required this.recruitmentFields,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
    required this.replyCount,
    required this.likeCount,
    required this.likedByMe,
    this.myReaction,
    this.quotedPost,
    this.poll,
    this.replyPolicy = 'ANYONE',
    this.boostCount = 0,
    this.boostedByMe = false,
  });

  final String id;
  final String roomId;
  final String roomSlug;
  final String roomName;
  final PostAuthorDto author;
  final String body;
  final String status;
  final String postType; // GENERAL | RECRUITMENT
  final RecruitmentFieldsDto? recruitmentFields;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PostAttachmentDto> attachments;
  final int replyCount;
  final int likeCount;
  final bool likedByMe;
  /// P6.4: viewer's specific emoji (HEART/THUMBS_UP/FIRE/THINK/IDEA/LAUGH),
  /// or null if the viewer has not reacted.
  final String? myReaction;
  final QuotedPostRefDto? quotedPost;
  /// P6.5: poll sidecar (1:1 with the post) or null.
  final PollDto? poll;
  /// P6.7: ANYONE / FOLLOWERS / MENTIONED_ONLY / DISABLED.
  final String replyPolicy;
  /// P6.6: total boosts (server-side counter).
  final int boostCount;
  /// P6.6: viewer has boosted this post.
  final bool boostedByMe;

  bool get isRecruitment => postType == 'RECRUITMENT';

  PostDto copyWith({
    int? likeCount,
    bool? likedByMe,
    String? myReaction,
    bool clearMyReaction = false,
    int? replyCount,
    RecruitmentFieldsDto? recruitmentFields,
  }) =>
      PostDto(
        id: id,
        roomId: roomId,
        roomSlug: roomSlug,
        roomName: roomName,
        author: author,
        body: body,
        status: status,
        postType: postType,
        recruitmentFields: recruitmentFields ?? this.recruitmentFields,
        createdAt: createdAt,
        updatedAt: updatedAt,
        attachments: attachments,
        replyCount: replyCount ?? this.replyCount,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
        quotedPost: quotedPost,
      );

  factory PostDto.fromJson(Map<String, dynamic> json) {
    final roomMap = (json['room'] as Map).cast<String, dynamic>();
    final counts = (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rfRaw = json['recruitment_fields'];
    final quotedRaw = json['quoted_post'];
    return PostDto(
      id: json['id'] as String,
      roomId: roomMap['id'] as String,
      roomSlug: roomMap['slug'] as String,
      roomName: roomMap['name'] as String,
      author: PostAuthorDto.fromJson(
          (json['author'] as Map).cast<String, dynamic>()),
      body: json['body'] as String,
      status: json['status'] as String? ?? 'VISIBLE',
      postType: json['post_type'] as String? ?? 'GENERAL',
      recruitmentFields: rfRaw is Map
          ? RecruitmentFieldsDto.fromJson(rfRaw.cast<String, dynamic>())
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      attachments: (json['attachments'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(PostAttachmentDto.fromJson)
          .toList(growable: false),
      replyCount: counts['reply_count'] as int? ?? 0,
      likeCount: counts['like_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      myReaction: json['my_reaction'] as String?,
      quotedPost: quotedRaw is Map
          ? QuotedPostRefDto.fromJson(quotedRaw.cast<String, dynamic>())
          : null,
      poll: json['poll'] is Map
          ? PollDto.fromJson(
              (json['poll'] as Map).cast<String, dynamic>(),
            )
          : null,
      replyPolicy: json['reply_policy'] as String? ?? 'ANYONE',
      boostCount: (counts['boost_count'] as int?) ?? 0,
      boostedByMe: json['boosted_by_me'] as bool? ?? false,
    );
  }
}

class TimelinePage {
  const TimelinePage({required this.items, required this.nextCursor});
  final List<PostDto> items;
  final String? nextCursor;

  factory TimelinePage.fromJson(Map<String, dynamic> json) => TimelinePage(
        items: (json['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(PostDto.fromJson)
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
      );
}
