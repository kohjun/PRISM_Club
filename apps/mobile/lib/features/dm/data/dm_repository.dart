import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'dm_dto.dart';

/// Client for the P6.9 scoped-DM endpoints. All server gates
/// (party-only, channel OPEN, block, rate limit) are authoritative;
/// the mobile only renders what the API returns.
class DmRepository {
  DmRepository(this._ref);
  final Ref _ref;

  Future<DmChannelListDto> listChannels() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/dm/channels');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '메시지함을 불러오지 못했어요.', res.statusCode);
      }
      return DmChannelListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<DmMessageListDto> listMessages(String channelId, {String? cursor}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/dm/channels/$channelId/messages',
            queryParameters: cursor != null ? {'cursor': cursor} : null,
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '대화를 불러오지 못했어요.', res.statusCode);
      }
      return DmMessageListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<DmMessageDto> send(String channelId, String body) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/dm/channels/$channelId/messages',
            data: {'body': body},
          );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '메시지를 보내지 못했어요.', res.statusCode);
      }
      return DmMessageDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Resolve-or-create a workflow-scoped channel. `counterpartId` is
  /// required only when the post author opens a RECRUITMENT channel.
  Future<DmChannelDto> resolveOrCreate({
    required String scope,
    required String refId,
    String? counterpartId,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/dm/channels',
        data: {
          'scope': scope,
          'ref_id': refId,
          'counterpart_id': ?counterpartId,
        },
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '대화를 열지 못했어요.', res.statusCode);
      }
      return DmChannelDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> markRead(String channelId) async {
    // Best-effort: a failed read-receipt should never surface an error.
    try {
      await _ref.read(dioProvider).post<dynamic>('/dm/channels/$channelId/read');
    } catch (_) {
      // ignore
    }
  }

  Future<void> reportMessage(String messageId, {String reason = 'inappropriate'}) async {
    try {
      await _ref.read(dioProvider).post<dynamic>(
        '/reports',
        data: {
          'target_type': 'DM_MESSAGE',
          'target_id': messageId,
          'reason': reason,
        },
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final dmRepositoryProvider = Provider<DmRepository>((ref) => DmRepository(ref));

final dmChannelsProvider = FutureProvider<DmChannelListDto>((ref) {
  return ref.read(dmRepositoryProvider).listChannels();
});

final dmThreadProvider =
    FutureProvider.family<DmMessageListDto, String>((ref, channelId) {
  return ref.read(dmRepositoryProvider).listMessages(channelId);
});
