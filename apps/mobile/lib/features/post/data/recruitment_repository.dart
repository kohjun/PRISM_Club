import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'recruitment_dto.dart';

class RecruitmentRepository {
  RecruitmentRepository(this._ref);
  final Ref _ref;

  Future<RecruitmentApplicationDto> apply(
    String postId, {
    String? message,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/posts/$postId/apply',
            data: {
              if (message != null && message.isNotEmpty) 'message': message,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'APPLY_FAILED',
          status: res.statusCode,
        );
      }
      return RecruitmentApplicationDto.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> withdraw(String postId) async {
    try {
      await _ref.read(dioProvider).delete<dynamic>('/posts/$postId/apply');
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ApplicationsListDto> listApplications(
    String postId, {
    String? status,
    String? cursor,
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/posts/$postId/applications',
            queryParameters: {
              if (status != null) 'status': status,
              if (cursor != null) 'cursor': cursor,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load applications',
          res.statusCode,
        );
      }
      return ApplicationsListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<RecruitmentApplicationDto> decide(
    String applicationId,
    String decision,
  ) async {
    try {
      final res = await _ref.read(dioProvider).patch<dynamic>(
            '/applications/$applicationId',
            data: {'decision': decision},
          );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'DECIDE_FAILED',
          status: res.statusCode,
        );
      }
      return RecruitmentApplicationDto.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<MyApplicationsListDto> listMine({
    String? status,
    String? cursor,
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/applications',
            queryParameters: {
              if (status != null) 'status': status,
              if (cursor != null) 'cursor': cursor,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load applications',
          res.statusCode,
        );
      }
      return MyApplicationsListDto.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final recruitmentRepositoryProvider =
    Provider<RecruitmentRepository>((ref) => RecruitmentRepository(ref));

final postApplicationsProvider =
    FutureProvider.family<ApplicationsListDto, String>(
  (ref, postId) =>
      ref.read(recruitmentRepositoryProvider).listApplications(postId),
);

final myApplicationsProvider = FutureProvider<MyApplicationsListDto>(
  (ref) => ref.read(recruitmentRepositoryProvider).listMine(),
);
