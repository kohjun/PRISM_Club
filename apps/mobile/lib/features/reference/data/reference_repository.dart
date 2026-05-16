import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'reference_dto.dart';

class ReferenceRepository {
  ReferenceRepository(this._ref);
  final Ref _ref;

  Future<ReferenceDto> create({
    required String url,
    required String title,
    required String type,
    String? sourceName,
    String? thumbnailUrl,
    String? summary,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/references',
        data: {
          'url': url,
          'title': title,
          'type': type,
          if (sourceName != null && sourceName.isNotEmpty) 'source_name': sourceName,
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            'thumbnail_url': thumbnailUrl,
          if (summary != null && summary.isNotEmpty) 'summary': summary,
        },
      );
      if (res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Reference create failed', res.statusCode);
      }
      return ReferenceDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final referenceRepositoryProvider =
    Provider<ReferenceRepository>((ref) => ReferenceRepository(ref));
