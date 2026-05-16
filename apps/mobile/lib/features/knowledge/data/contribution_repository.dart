import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'contribution_dto.dart';

class ContributionRepository {
  ContributionRepository(this._ref);
  final Ref _ref;

  Future<ContributionDetailDto> submit(
    String categorySlug,
    SubmitContributionRequest req,
  ) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/categories/$categorySlug/knowledge-contributions',
            data: req.toJson(),
          );
      if (res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Submit failed', res.statusCode);
      }
      return ContributionDetailDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<ContributionDto>> listMine({String? status}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/me/contributions',
        queryParameters: {'status': ?status},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load contributions', res.statusCode);
      }
      final items = (res.data as Map)['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(ContributionDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<ContributionDto>> listAdmin({String? status, String? categorySlug}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/admin/knowledge-contributions',
        queryParameters: {
          'status': ?status,
          'categorySlug': ?categorySlug,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load curation queue', res.statusCode);
      }
      final items = (res.data as Map)['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(ContributionDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ContributionDetailDto> getById(String id) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/admin/knowledge-contributions/$id');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load contribution', res.statusCode);
      }
      return ContributionDetailDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ContributionDetailDto> resolve(
    String id,
    ResolveContributionRequest req,
  ) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/admin/knowledge-contributions/$id/resolve',
            data: req.toJson(),
          );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Resolve failed', res.statusCode);
      }
      return ContributionDetailDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> withdraw(String id) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .delete<dynamic>('/knowledge-contributions/$id');
      if (res.statusCode != 204) {
        throw ApiError('UNEXPECTED', 'Withdraw failed', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final contributionRepositoryProvider =
    Provider<ContributionRepository>((ref) => ContributionRepository(ref));

final myContributionsProvider =
    FutureProvider<List<ContributionDto>>((ref) {
  return ref.read(contributionRepositoryProvider).listMine();
});

final adminContributionsProvider =
    FutureProvider.family<List<ContributionDto>, String>((ref, status) {
  return ref.read(contributionRepositoryProvider).listAdmin(status: status);
});

final contributionDetailProvider =
    FutureProvider.family<ContributionDetailDto, String>((ref, id) {
  return ref.read(contributionRepositoryProvider).getById(id);
});
