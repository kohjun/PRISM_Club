class ReportDto {
  const ReportDto({
    required this.id,
    required this.reporterId,
    required this.reporterNickname,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.status,
    required this.resolution,
    required this.resolvedAt,
    required this.resolverNote,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String? reporterNickname;
  final String targetType; // POST | REPLY | ROOM | USER | REFERENCE
  final String targetId;
  final String reason;
  final String? details;
  final String status; // OPEN | RESOLVED | DISMISSED
  final String? resolution; // HIDDEN | RESTORED | DISMISSED
  final DateTime? resolvedAt;
  final String? resolverNote;
  final DateTime createdAt;

  factory ReportDto.fromJson(Map<String, dynamic> json) {
    final reporter = (json['reporter'] as Map?)?.cast<String, dynamic>() ?? {};
    return ReportDto(
      id: json['id'] as String,
      reporterId: reporter['id'] as String? ?? '',
      reporterNickname: reporter['nickname'] as String?,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      reason: json['reason'] as String,
      details: json['details'] as String?,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolverNote: json['resolver_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReportListDto {
  const ReportListDto({required this.items});
  final List<ReportDto> items;

  factory ReportListDto.fromJson(Map<String, dynamic> json) => ReportListDto(
        items: ((json['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ReportDto.fromJson)
            .toList(growable: false),
      );
}

class ModerationActionDto {
  const ModerationActionDto({
    required this.id,
    required this.actorNickname,
    required this.action,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String? actorNickname;
  final String action; // HIDE | RESTORE | DISMISS
  final String? note;
  final DateTime createdAt;

  factory ModerationActionDto.fromJson(Map<String, dynamic> json) {
    final actor = (json['actor'] as Map?)?.cast<String, dynamic>() ?? {};
    return ModerationActionDto(
      id: json['id'] as String,
      actorNickname: actor['nickname'] as String?,
      action: json['action'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReportTargetSummaryDto {
  const ReportTargetSummaryDto({
    required this.type,
    required this.id,
    required this.preview,
    required this.status,
    required this.exists,
  });

  final String type;
  final String id;
  final String preview;
  final String? status;
  final bool exists;

  factory ReportTargetSummaryDto.fromJson(Map<String, dynamic> json) =>
      ReportTargetSummaryDto(
        type: json['type'] as String,
        id: json['id'] as String,
        preview: json['preview'] as String? ?? '',
        status: json['status'] as String?,
        exists: json['exists'] as bool? ?? false,
      );
}

class ReportDetailDto extends ReportDto {
  const ReportDetailDto({
    required super.id,
    required super.reporterId,
    required super.reporterNickname,
    required super.targetType,
    required super.targetId,
    required super.reason,
    required super.details,
    required super.status,
    required super.resolution,
    required super.resolvedAt,
    required super.resolverNote,
    required super.createdAt,
    required this.target,
    required this.actions,
  });

  final ReportTargetSummaryDto target;
  final List<ModerationActionDto> actions;

  factory ReportDetailDto.fromDetailJson(Map<String, dynamic> json) {
    final base = ReportDto.fromJson(json);
    final target = ReportTargetSummaryDto.fromJson(
        (json['target'] as Map).cast<String, dynamic>());
    final actions = ((json['actions'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ModerationActionDto.fromJson)
        .toList(growable: false);
    return ReportDetailDto(
      id: base.id,
      reporterId: base.reporterId,
      reporterNickname: base.reporterNickname,
      targetType: base.targetType,
      targetId: base.targetId,
      reason: base.reason,
      details: base.details,
      status: base.status,
      resolution: base.resolution,
      resolvedAt: base.resolvedAt,
      resolverNote: base.resolverNote,
      createdAt: base.createdAt,
      target: target,
      actions: actions,
    );
  }
}
