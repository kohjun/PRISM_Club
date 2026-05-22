class RecruitmentApplicationDto {
  const RecruitmentApplicationDto({
    required this.id,
    required this.postId,
    required this.applicantId,
    required this.applicantNickname,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String postId;
  final String applicantId;
  final String? applicantNickname;
  final String? message;
  final String status; // PENDING | ACCEPTED | REJECTED | WITHDRAWN
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecruitmentApplicationDto.fromJson(Map<String, dynamic> j) {
    final applicant = (j['applicant'] as Map).cast<String, dynamic>();
    return RecruitmentApplicationDto(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      applicantId: applicant['id'] as String,
      applicantNickname: applicant['nickname'] as String?,
      message: j['message'] as String?,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }
}

class ApplicationsListDto {
  const ApplicationsListDto({
    required this.items,
    required this.nextCursor,
    required this.recruitmentStatus,
    required this.acceptedCount,
    required this.capacity,
  });

  final List<RecruitmentApplicationDto> items;
  final String? nextCursor;
  final String recruitmentStatus;
  final int acceptedCount;
  final int? capacity;

  factory ApplicationsListDto.fromJson(Map<String, dynamic> j) =>
      ApplicationsListDto(
        items: (j['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(RecruitmentApplicationDto.fromJson)
            .toList(growable: false),
        nextCursor: j['next_cursor'] as String?,
        recruitmentStatus: j['recruitment_status'] as String? ?? 'OPEN',
        acceptedCount: j['accepted_count'] as int? ?? 0,
        capacity: j['capacity'] as int?,
      );
}

class MyApplicationEntryDto {
  const MyApplicationEntryDto({
    required this.application,
    required this.postId,
    required this.bodyPreview,
    required this.roomSlug,
    required this.recruitmentStatus,
  });

  final RecruitmentApplicationDto application;
  final String postId;
  final String bodyPreview;
  final String roomSlug;
  final String recruitmentStatus;

  factory MyApplicationEntryDto.fromJson(Map<String, dynamic> j) {
    final post = (j['post'] as Map).cast<String, dynamic>();
    return MyApplicationEntryDto(
      application: RecruitmentApplicationDto.fromJson(
        (j['application'] as Map).cast<String, dynamic>(),
      ),
      postId: post['id'] as String,
      bodyPreview: post['body_preview'] as String? ?? '',
      roomSlug: post['room_slug'] as String? ?? '',
      recruitmentStatus: post['status'] as String? ?? 'OPEN',
    );
  }
}

class MyApplicationsListDto {
  const MyApplicationsListDto({
    required this.items,
    required this.nextCursor,
  });

  final List<MyApplicationEntryDto> items;
  final String? nextCursor;

  factory MyApplicationsListDto.fromJson(Map<String, dynamic> j) =>
      MyApplicationsListDto(
        items: (j['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(MyApplicationEntryDto.fromJson)
            .toList(growable: false),
        nextCursor: j['next_cursor'] as String?,
      );
}
