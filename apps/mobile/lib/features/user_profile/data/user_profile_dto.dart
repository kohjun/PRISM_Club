import '../../../core/json_helpers.dart';
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
        nickname: asStringOrNull(json, 'nickname'),
        avatarUrl: asStringOrNull(json, 'avatar_url'),
        status: asString(json, 'status', fallback: 'ACTIVE'),
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
        bio: asStringOrNull(json, 'bio'),
        region: asStringOrNull(json, 'region'),
        interests: asStringList(json, 'interests'),
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
        postCount: asInt(json, 'post_count'),
        roomCount: asInt(json, 'room_count'),
        followerCount: asInt(json, 'follower_count'),
        followingCount: asInt(json, 'following_count'),
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
        topicHubTitle: asString(json, 'topic_hub_title'),
        categorySlug: asString(json, 'category_slug'),
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
        roles: asStringList(json, 'roles'),
        counts: ProfileCountsDto.fromJson(
            (json['counts'] as Map).cast<String, dynamic>()),
        recentPosts: asObjectList(json, 'recent_posts', PostDto.fromJson),
        userRooms: asObjectList(json, 'user_rooms', RoomSummaryDto.fromJson),
        approvedContributions: asObjectList(
            json, 'approved_contributions', ApprovedContributionDto.fromJson),
        isSelf: asBool(json, 'is_self'),
        isFollowing: asBool(json, 'is_following'),
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
        followed: asBool(json, 'followed'),
        followerCount: asInt(json, 'follower_count'),
      );
}
