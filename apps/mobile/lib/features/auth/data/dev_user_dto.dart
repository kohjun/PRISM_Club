class DevUserDto {
  const DevUserDto({required this.id, required this.nickname});
  final String id;
  final String nickname;

  factory DevUserDto.fromJson(Map<String, dynamic> json) => DevUserDto(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
      );
}
