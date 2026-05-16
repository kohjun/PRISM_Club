import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'room_detail_dto.dart';

class CreateRoomRequest {
  CreateRoomRequest({
    required this.name,
    this.description,
    required this.roomType,
    this.pinnedEventCardId,
    this.pinnedReferenceId,
  });

  final String name;
  final String? description;
  final String roomType; // DISCUSSION | EVENT_REACTION | REFERENCE | IDEA | RECRUITMENT | SOCIAL
  final String? pinnedEventCardId;
  final String? pinnedReferenceId;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'room_type': roomType,
        if (pinnedEventCardId != null) 'pinned_event_card_id': pinnedEventCardId,
        if (pinnedReferenceId != null) 'pinned_reference_id': pinnedReferenceId,
      };
}

class RoomRepository {
  RoomRepository(this._ref);
  final Ref _ref;

  Future<RoomDetailDto> create(String categorySlug, CreateRoomRequest req) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/categories/$categorySlug/rooms',
            data: req.toJson(),
          );
      if (res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Room create failed', res.statusCode);
      }
      return RoomDetailDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<RoomDetailDto> getBySlug(String slug) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/rooms/$slug');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Room load failed', res.statusCode);
      }
      return RoomDetailDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final roomRepositoryProvider =
    Provider<RoomRepository>((ref) => RoomRepository(ref));

final roomDetailProvider =
    FutureProvider.family<RoomDetailDto, String>((ref, slug) {
  return ref.read(roomRepositoryProvider).getBySlug(slug);
});
