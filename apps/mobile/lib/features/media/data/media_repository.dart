import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'media_dto.dart';

class MediaRepository {
  MediaRepository(this._ref);
  final Ref _ref;

  /// Upload bytes as a single multipart 'file' field.
  Future<MediaAssetDto> uploadImage({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: contentType != null
              ? DioMediaType.parse(contentType)
              : null,
        ),
      });
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/media/upload',
            data: form,
            options: Options(headers: {
              'Content-Type': 'multipart/form-data',
            }),
          );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Failed to upload image', res.statusCode);
      }
      return MediaAssetDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final mediaRepositoryProvider =
    Provider<MediaRepository>((ref) => MediaRepository(ref));
