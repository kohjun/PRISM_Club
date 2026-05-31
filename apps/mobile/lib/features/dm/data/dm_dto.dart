import '../../../core/json_helpers.dart';

/// P6.9 — Scoped DM DTOs (workflow-bounded private 1:1 channels).

class DmCounterpartDto {
  const DmCounterpartDto({required this.id, required this.nickname});
  final String id;
  final String? nickname;

  factory DmCounterpartDto.fromJson(Map<String, dynamic> j) => DmCounterpartDto(
        id: asString(j, 'id'),
        nickname: asStringOrNull(j, 'nickname'),
      );
}

class DmChannelDto {
  const DmChannelDto({
    required this.id,
    required this.scope,
    required this.refId,
    required this.counterpart,
    required this.status,
    required this.lastMessageAt,
    required this.unread,
    required this.createdAt,
  });

  final String id;
  final String scope; // RECRUITMENT | CONTRIBUTION
  final String refId;
  final DmCounterpartDto counterpart;
  final String status; // OPEN | CLOSED
  final DateTime? lastMessageAt;
  final bool unread;
  final DateTime? createdAt;

  bool get isClosed => status == 'CLOSED';

  factory DmChannelDto.fromJson(Map<String, dynamic> j) => DmChannelDto(
        id: asString(j, 'id'),
        scope: asString(j, 'scope'),
        refId: asString(j, 'ref_id'),
        counterpart: DmCounterpartDto.fromJson(
          asMap(j, 'counterpart') ?? const <String, dynamic>{},
        ),
        status: asString(j, 'status', fallback: 'OPEN'),
        lastMessageAt: asDateTimeOrNull(j, 'last_message_at'),
        unread: asBool(j, 'unread'),
        createdAt: asDateTimeOrNull(j, 'created_at'),
      );
}

class DmChannelListDto {
  const DmChannelListDto({required this.items});
  final List<DmChannelDto> items;

  factory DmChannelListDto.fromJson(Map<String, dynamic> j) =>
      DmChannelListDto(items: asObjectList(j, 'items', DmChannelDto.fromJson));
}

class DmMessageDto {
  const DmMessageDto({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.body,
    required this.status,
    required this.mine,
    required this.createdAt,
  });

  final String id;
  final String channelId;
  final String senderId;
  final String body;
  final String status; // VISIBLE | HIDDEN
  final bool mine;
  final DateTime? createdAt;

  bool get isHidden => status == 'HIDDEN';

  factory DmMessageDto.fromJson(Map<String, dynamic> j) => DmMessageDto(
        id: asString(j, 'id'),
        channelId: asString(j, 'channel_id'),
        senderId: asString(j, 'sender_id'),
        body: asString(j, 'body'),
        status: asString(j, 'status', fallback: 'VISIBLE'),
        mine: asBool(j, 'mine'),
        createdAt: asDateTimeOrNull(j, 'created_at'),
      );
}

class DmMessageListDto {
  const DmMessageListDto({
    required this.items,
    required this.nextCursor,
    required this.channelStatus,
  });
  final List<DmMessageDto> items;
  final String? nextCursor;
  final String channelStatus; // OPEN | CLOSED

  bool get isClosed => channelStatus == 'CLOSED';

  factory DmMessageListDto.fromJson(Map<String, dynamic> j) => DmMessageListDto(
        items: asObjectList(j, 'items', DmMessageDto.fromJson),
        nextCursor: asStringOrNull(j, 'next_cursor'),
        channelStatus: asString(j, 'channel_status', fallback: 'OPEN'),
      );
}
