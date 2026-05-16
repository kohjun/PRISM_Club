class RoomSummaryDto {
  const RoomSummaryDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.origin,
    required this.roomType,
    required this.ownerNickname,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String origin; // OFFICIAL | USER
  final String roomType;
  final String? ownerNickname;

  bool get isUserCreated => origin == 'USER';

  factory RoomSummaryDto.fromJson(Map<String, dynamic> json) => RoomSummaryDto(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        origin: json['origin'] as String,
        roomType: json['room_type'] as String,
        ownerNickname: json['owner_nickname'] as String?,
      );
}
