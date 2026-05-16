/// Mirrors the server's `recruitment_fields` JSON payload returned on
/// RECRUITMENT-type posts.
class RecruitmentFieldsDto {
  const RecruitmentFieldsDto({
    required this.role,
    required this.schedule,
    required this.location,
    required this.compensation,
    required this.capacity,
    required this.applicationMethod,
    required this.status,
  });

  final String role;
  final String schedule;
  final String location;
  final String compensation;
  final int capacity;
  final String applicationMethod;
  final String status; // 'OPEN' | 'CLOSED' | 'FILLED'

  bool get isOpen => status == 'OPEN';

  factory RecruitmentFieldsDto.fromJson(Map<String, dynamic> json) {
    final rawCapacity = json['capacity'];
    return RecruitmentFieldsDto(
      role: (json['role'] as String?) ?? '',
      schedule: (json['schedule'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      compensation: (json['compensation'] as String?) ?? '',
      capacity: rawCapacity is int
          ? rawCapacity
          : (rawCapacity is num
              ? rawCapacity.toInt()
              : int.tryParse('${rawCapacity ?? 0}') ?? 0),
      applicationMethod: (json['application_method'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'OPEN',
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'schedule': schedule,
        'location': location,
        'compensation': compensation,
        'capacity': capacity,
        'application_method': applicationMethod,
        'status': status,
      };
}
