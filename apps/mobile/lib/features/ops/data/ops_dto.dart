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
      pendingContributions: pc['count'] as int? ?? 0,
      openReports: or['count'] as int? ?? 0,
      recruitmentOpen: rp['count_open'] as int? ?? 0,
      recruitmentTotal: rp['count_total'] as int? ?? 0,
      recentUserCount: ru['count'] as int? ?? 0,
      recentUsers: ((ru['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsUserRow.fromJson)
          .toList(growable: false),
      recentRoomCount: rr['count'] as int? ?? 0,
      recentRooms: ((rr['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsRoomRow.fromJson)
          .toList(growable: false),
      recentPostCount: rPosts['count'] as int? ?? 0,
      recentPosts: ((rPosts['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OpsPostRow.fromJson)
          .toList(growable: false),
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
        nickname: j['nickname'] as String?,
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
        bodyPreview: j['body_preview'] as String? ?? '',
        roomSlug: j['room_slug'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
