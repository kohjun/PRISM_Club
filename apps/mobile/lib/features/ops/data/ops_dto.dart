import '../../../core/json_helpers.dart';

class OpsSummaryDto {
  const OpsSummaryDto({
    required this.pendingContributions,
    required this.openReports,
    required this.recruitmentOpen,
    required this.recruitmentTotal,
    required this.recentUserCount,
    required this.recentUsers,
    required this.recentRoomCount,
    required this.recentRooms,
    required this.recentPostCount,
    required this.recentPosts,
  });

  final int pendingContributions;
  final int openReports;
  final int recruitmentOpen;
  final int recruitmentTotal;
  final int recentUserCount;
  final List<OpsUserRow> recentUsers;
  final int recentRoomCount;
  final List<OpsRoomRow> recentRooms;
  final int recentPostCount;
  final List<OpsPostRow> recentPosts;

  factory OpsSummaryDto.fromJson(Map<String, dynamic> json) {
    final pc = (json['pending_contributions'] as Map).cast<String, dynamic>();
    final or = (json['open_reports'] as Map).cast<String, dynamic>();
    final rp = (json['recruitment_posts'] as Map).cast<String, dynamic>();
    final ru = (json['recent_users'] as Map).cast<String, dynamic>();
    final rr = (json['recent_rooms'] as Map).cast<String, dynamic>();
    final rPosts = (json['recent_posts'] as Map).cast<String, dynamic>();
    return OpsSummaryDto(
      pendingContributions: asInt(pc, 'count'),
      openReports: asInt(or, 'count'),
      recruitmentOpen: asInt(rp, 'count_open'),
      recruitmentTotal: asInt(rp, 'count_total'),
      recentUserCount: asInt(ru, 'count'),
      recentUsers: asObjectList(ru, 'items', OpsUserRow.fromJson),
      recentRoomCount: asInt(rr, 'count'),
      recentRooms: asObjectList(rr, 'items', OpsRoomRow.fromJson),
      recentPostCount: asInt(rPosts, 'count'),
      recentPosts: asObjectList(rPosts, 'items', OpsPostRow.fromJson),
    );
  }
}

class OpsUserRow {
  const OpsUserRow({
    required this.id,
    required this.nickname,
    required this.createdAt,
  });
  final String id;
  final String? nickname;
  final DateTime createdAt;
  factory OpsUserRow.fromJson(Map<String, dynamic> j) => OpsUserRow(
        id: j['id'] as String,
        nickname: asStringOrNull(j, 'nickname'),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class OpsRoomRow {
  const OpsRoomRow({
    required this.id,
    required this.slug,
    required this.name,
    required this.createdAt,
  });
  final String id;
  final String slug;
  final String name;
  final DateTime createdAt;
  factory OpsRoomRow.fromJson(Map<String, dynamic> j) => OpsRoomRow(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class OpsPostRow {
  const OpsPostRow({
    required this.id,
    required this.bodyPreview,
    required this.roomSlug,
    required this.createdAt,
  });
  final String id;
  final String bodyPreview;
  final String roomSlug;
  final DateTime createdAt;
  factory OpsPostRow.fromJson(Map<String, dynamic> j) => OpsPostRow(
        id: j['id'] as String,
        bodyPreview: asString(j, 'body_preview'),
        roomSlug: asString(j, 'room_slug'),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
