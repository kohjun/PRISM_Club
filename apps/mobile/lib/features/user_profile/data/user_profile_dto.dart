import '../../post/data/post_dto.dart';
import '../../room/data/room_summary_dto.dart';

class ProfileUserDto {
  const ProfileUserDto({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String? nickname;
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;

  factory ProfileUserDto.fromJson(Map<String, dynamic> json) => ProfileUserDto(
        id: json['id'] as String,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ProfileSubDto {
  const ProfileSubDto({
    required this.bio,
    required this.region,
    required this.interests,
  });

  final String? bio;
  final String? region;
  final List<String> interests;

  factory ProfileSubDto.fromJson(Map<String, dynamic> json) => ProfileSubDto(
        bio: json['bio'] as String?,
        region: json['region'] as String?,
        interests: ((json['interests'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class ProfileCountsDto {
  const ProfileCountsDto({
    required this.postCount,
    required this.roomCount,
    required this.followerCount,
    required this.followingCount,
  });

  final int postCount;
  final int roomCount;
  final int followerCount;
  final int followingCount;

  factory ProfileCountsDto.fromJson(Map<String, dynamic> json) => ProfileCountsDto(
        postCount: json['post_count'] as int? ?? 0,
        roomCount: json['room_count'] as int? ?? 0,
        followerCount: json['follower_count'] as int? ?? 0,
        followingCount: json['following_count'] as int? ?? 0,
      );
}

class ApprovedContributionDto {
  const ApprovedContributionDto({
    required this.id,
    required this.topicHubTitle,
    required this.categorySlug,
    required this.resolvedAt,
  });

  final String id;
  final String topicHubTitle;
  final String categorySlug;
  final DateTime resolvedAt;

  factory ApprovedContributionDto.fromJson(Map<String, dynamic> json) =>
      ApprovedContributionDto(
        id: json['id'] as String,
        topicHubTitle: json['topic_hub_title'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
        resolvedAt: DateTime.parse(json['resolved_at'] as String),
      );
}

class UserProfileBundleDto {
  const UserProfileBundleDto({
    required this.user,
    required this.profile,
    required this.roles,
    required this.counts,
    required this.recentPosts,
    required this.userRooms,
    required this.approvedContributions,
    required this.isSelf,
    required this.isFollowing,
  });

  final ProfileUserDto user;
  final ProfileSubDto profile;
  final List<String> roles;
  final ProfileCountsDto counts;
  final List<PostDto> recentPosts;
  final List<RoomSummaryDto> userRooms;
  final List<ApprovedContributionDto> approvedContributions;
  final bool isSelf;
  final bool isFollowing;

  factory UserProfileBundleDto.fromJson(Map<String, dynamic> json) =>
      UserProfileBundleDto(
        user: ProfileUserDto.fromJson(
            (json['user'] as Map).cast<String, dynamic>()),
        profile: ProfileSubDto.fromJson(
            (json['profile'] as Map).cast<String, dynamic>()),
        roles: ((json['roles'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        counts: ProfileCountsDto.fromJson(
            (json['counts'] as Map).cast<String, dynamic>()),
        recentPosts: ((json['recent_posts'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PostDto.fromJson)
            .toList(growable: false),
        userRooms: ((json['user_rooms'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RoomSummaryDto.fromJson)
            .toList(growable: false),
        approvedContributions:
            ((json['approved_contributions'] as List?) ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(ApprovedContributionDto.fromJson)
                .toList(growable: false),
        isSelf: json['is_self'] as bool? ?? false,
        isFollowing: json['is_following'] as bool? ?? false,
      );
}

class UpdateProfileInput {
  const UpdateProfileInput({
    this.bio,
    this.region,
    this.interests,
    this.nickname,
    this.avatarUrl,
    this.clearAvatar = false,
  });

  final String? bio;
  final String? region;
  final List<String>? interests;
  final String? nickname;
  final String? avatarUrl;
  final bool clearAvatar;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (bio != null) m['bio'] = bio;
    if (region != null) m['region'] = region;
    if (interests != null) m['interests'] = interests;
    if (nickname != null) m['nickname'] = nickname;
    if (clearAvatar) {
      m['avatar_url'] = null;
    } else if (avatarUrl != null) {
      m['avatar_url'] = avatarUrl;
    }
    return m;
  }
}

class UserFollowStateDto {
  const UserFollowStateDto({required this.followed, required this.followerCount});

  final bool followed;
  final int followerCount;

  factory UserFollowStateDto.fromJson(Map<String, dynamic> json) =>
      UserFollowStateDto(
        followed: json['followed'] as bool? ?? false,
        followerCount: json['follower_count'] as int? ?? 0,
      );
}
