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

  factory MeDto.fromJson(Map<String, dynamic> json) => MeDto(
        id: json['id'] as String,
        status: json['status'] as String? ?? 'ACTIVE',
        nickname: json['nickname'] as String?,
        region: json['region'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        roles: ((json['roles'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}
