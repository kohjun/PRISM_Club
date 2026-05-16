import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'post_dto.dart';

class CreatePostAttachment {
  const CreatePostAttachment({required this.attachmentType, required this.targetId});
  final String attachmentType;
  final String targetId;

  Map<String, dynamic> toJson() => {
        'attachment_type': attachmentType,
        'target_id': targetId,
      };
}

class PostRepository {
  PostRepository(this._ref);
  final Ref _ref;

  Future<TimelinePage> getTimeline(String roomSlug,
      {String? cursor, int? limit}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/rooms/$roomSlug/timeline',
        queryParameters: {
          'cursor': ?cursor,
          'limit': ?limit,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Timeline load failed', res.statusCode);
      }
      return TimelinePage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<PostDto> create(
    String roomSlug, {
    required String body,
    List<CreatePostAttachment> attachments = const [],
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/rooms/$roomSlug/posts',
        data: {
          'body': body,
          if (attachments.isNotEmpty)
            'attachments': attachments.map((a) => a.toJson()).toList(),
        },
      );
      if (res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Post create failed', res.statusCode);
      }
      return PostDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<PostDto> getById(String id) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/posts/$id');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Post load failed', res.statusCode);
      }
      return PostDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final res = await _ref.read(dioProvider).delete<dynamic>('/posts/$id');
      if (res.statusCode != 204) {
        throw ApiError('UNEXPECTED', 'Post delete failed', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final postRepositoryProvider =
    Provider<PostRepository>((ref) => PostRepository(ref));

final timelineProvider =
    FutureProvider.family<TimelinePage, String>((ref, roomSlug) {
  return ref.read(postRepositoryProvider).getTimeline(roomSlug, limit: 20);
});
