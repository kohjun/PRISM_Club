import '../../../core/json_helpers.dart';

/// A room-scoped role grant (P6.12). Returned by
/// `GET /v1/rooms/:slug/roles`.
class RoomRoleDto {
  const RoomRoleDto({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.grantedAt,
  });

  final String userId;
  final String? nickname;
  final String role; // MODERATOR | MEMBER
  final String grantedAt;

  factory RoomRoleDto.fromJson(Map<String, dynamic> json) => RoomRoleDto(
        userId: asString(json, 'user_id'),
        nickname: asStringOrNull(json, 'nickname'),
        role: asString(json, 'role'),
        grantedAt: asString(json, 'granted_at'),
      );
}
