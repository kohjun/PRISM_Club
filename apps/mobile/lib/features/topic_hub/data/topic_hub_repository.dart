import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'topic_hub_dto.dart';

class TopicHubRepository {
  TopicHubRepository(this._ref);
  final Ref _ref;

  Future<TopicHubBundle> getByCategorySlug(String categorySlug) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/categories/$categorySlug/hub');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load Topic Hub', res.statusCode);
      }
      return TopicHubBundle.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final topicHubRepositoryProvider =
    Provider<TopicHubRepository>((ref) => TopicHubRepository(ref));

final topicHubProvider =
    FutureProvider.family<TopicHubBundle, String>((ref, categorySlug) {
  return ref.read(topicHubRepositoryProvider).getByCategorySlug(categorySlug);
});
