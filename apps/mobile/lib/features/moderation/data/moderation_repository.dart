import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'moderation_dto.dart';

class ModerationRepository {
  ModerationRepository(this._ref);
  final Ref _ref;

  Future<ReportDto> createReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/reports',
        data: {
          'target_type': targetType,
          'target_id': targetId,
          'reason': reason,
          if (details != null && details.isNotEmpty) 'details': details,
        },
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiError(
            'UNEXPECTED', 'Failed to create report', res.statusCode);
      }
      return ReportDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ReportListDto> listMine() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/me/reports');
      if (res.statusCode != 200) {
        throw ApiError(
            'UNEXPECTED', 'Failed to load my reports', res.statusCode);
      }
      return ReportListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ReportListDto> listQueue({String? status}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/admin/reports',
        queryParameters: {
          'status': ?status,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError(
            'UNEXPECTED', 'Failed to load moderation queue', res.statusCode);
      }
      return ReportListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ReportDetailDto> getDetail(String id) async {
    try {
      final res =
          await _ref.read(dioProvider).get<dynamic>('/admin/reports/$id');
      if (res.statusCode != 200) {
        throw ApiError(
            'UNEXPECTED', 'Failed to load report detail', res.statusCode);
      }
      return ReportDetailDto.fromDetailJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ReportDetailDto> resolve(String id,
      {required String action, String? note}) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/admin/reports/$id/resolve',
        data: {
          'action': action,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Failed to resolve report', res.statusCode);
      }
      return ReportDetailDto.fromDetailJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final moderationRepositoryProvider =
    Provider<ModerationRepository>((ref) => ModerationRepository(ref));

final myReportsProvider = FutureProvider<ReportListDto>((ref) {
  return ref.read(moderationRepositoryProvider).listMine();
});

final moderationQueueProvider = FutureProvider<ReportListDto>((ref) {
  return ref.read(moderationRepositoryProvider).listQueue();
});

final reportDetailProvider =
    FutureProvider.family<ReportDetailDto, String>((ref, id) {
  return ref.read(moderationRepositoryProvider).getDetail(id);
});
