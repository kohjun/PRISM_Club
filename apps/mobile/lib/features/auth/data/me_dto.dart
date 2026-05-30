import '../../../core/json_helpers.dart';

/// Response from `GET /v1/me`. Carries roles so role-gated UI surfaces
/// (e.g., the curator banner on SpaceList) can show/hide themselves.
class MeDto {
  const MeDto({
    required this.id,
    required this.status,
    required this.nickname,
    required this.region,
    required this.roles,
    this.avatarUrl,
    this.bio,
  });

  final String id;
  final String status;
  final String? nickname;
  final String? region;
  final List<String> roles;
  final String? avatarUrl;
  final String? bio;

  bool get isCurator => roles.contains('CURATOR') || roles.contains('ADMIN');

  bool get isPlanner =>
      roles.contains('VERIFIED_PLANNER') || roles.contains('ADMIN');

  bool get isModerator =>
      roles.contains('MODERATOR') || roles.contains('ADMIN');

  bool get isOps => isCurator || isModerator;

  factory MeDto.fromJson(Map<String, dynamic> json) => MeDto(
        // id is intentionally a hard cast (no fallback): a response
        // without an id is a contract violation we want to surface.
        id: json['id'] as String,
        status: asString(json, 'status', fallback: 'ACTIVE'),
        nickname: asStringOrNull(json, 'nickname'),
        region: asStringOrNull(json, 'region'),
        avatarUrl: asStringOrNull(json, 'avatar_url'),
        bio: asStringOrNull(json, 'bio'),
        roles: asStringList(json, 'roles'),
      );
}
