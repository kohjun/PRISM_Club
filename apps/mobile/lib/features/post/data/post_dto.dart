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

  bool get isRecruitment => postType == 'RECRUITMENT';

  PostDto copyWith({
    int? likeCount,
    bool? likedByMe,
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
      );

  factory PostDto.fromJson(Map<String, dynamic> json) {
    final roomMap = (json['room'] as Map).cast<String, dynamic>();
    final counts = (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rfRaw = json['recruitment_fields'];
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
