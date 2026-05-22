import 'post_dto.dart';

class ReplyDto {
  const ReplyDto({
    required this.id,
    required this.postId,
    required this.parentReplyId,
    required this.author,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.likeCount,
    required this.likedByMe,
    this.myReaction,
  });

  final String id;
  final String postId;
  final String? parentReplyId;
  final PostAuthorDto author;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final bool likedByMe;
  final String? myReaction;

  ReplyDto copyWith({
    int? likeCount,
    bool? likedByMe,
    String? myReaction,
    bool clearMyReaction = false,
  }) =>
      ReplyDto(
        id: id,
        postId: postId,
        parentReplyId: parentReplyId,
        author: author,
        body: body,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        myReaction:
            clearMyReaction ? null : (myReaction ?? this.myReaction),
      );

  factory ReplyDto.fromJson(Map<String, dynamic> json) => ReplyDto(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        parentReplyId: json['parent_reply_id'] as String?,
        author: PostAuthorDto.fromJson(
            (json['author'] as Map).cast<String, dynamic>()),
        body: json['body'] as String,
        status: json['status'] as String? ?? 'VISIBLE',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        likeCount: json['like_count'] as int? ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        myReaction: json['my_reaction'] as String?,
      );
}
