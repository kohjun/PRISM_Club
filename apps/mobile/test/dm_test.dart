import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dm/data/dm_dto.dart';
import 'package:mobile/features/dm/data/dm_repository.dart';
import 'package:mobile/features/dm/ui/dm_inbox_screen.dart';
import 'package:mobile/features/dm/ui/dm_thread_screen.dart';

/// Fake DM repository so the inbox/thread screens never hit Dio in tests
/// (avoids the "Timer still pending" trap). `implements` only needs the
/// public surface — the private `_ref` field is not part of it.
class _FakeDmRepo implements DmRepository {
  _FakeDmRepo({
    this.channels = const [],
    this.messages = const [],
    this.channelStatus = 'OPEN',
  });
  final List<DmChannelDto> channels;
  final List<DmMessageDto> messages;
  final String channelStatus;

  @override
  Future<DmChannelListDto> listChannels() async =>
      DmChannelListDto(items: channels);

  @override
  Future<DmMessageListDto> listMessages(String channelId, {String? cursor}) async =>
      DmMessageListDto(
        items: messages,
        nextCursor: null,
        channelStatus: channelStatus,
      );

  @override
  Future<DmMessageDto> send(String channelId, String body) async => DmMessageDto(
        id: 'new',
        channelId: channelId,
        senderId: 'me',
        body: body,
        status: 'VISIBLE',
        mine: true,
        createdAt: DateTime(2026),
      );

  @override
  Future<DmChannelDto> resolveOrCreate({
    required String scope,
    required String refId,
    String? counterpartId,
  }) async =>
      DmChannelDto(
        id: 'c1',
        scope: scope,
        refId: refId,
        counterpart: const DmCounterpartDto(id: 'u', nickname: 'peer'),
        status: 'OPEN',
        lastMessageAt: null,
        unread: false,
        createdAt: DateTime(2026),
      );

  @override
  Future<void> markRead(String channelId) async {}

  @override
  Future<void> reportMessage(String messageId, {String reason = 'inappropriate'}) async {}
}

Widget _wrap(Widget child, _FakeDmRepo repo) => ProviderScope(
      overrides: [dmRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    );

DmChannelDto _channel(String id, String nickname, {bool unread = false}) =>
    DmChannelDto(
      id: id,
      scope: 'RECRUITMENT',
      refId: 'p1',
      counterpart: DmCounterpartDto(id: 'u-$id', nickname: nickname),
      status: 'OPEN',
      lastMessageAt: DateTime(2026, 5, 1),
      unread: unread,
      createdAt: DateTime(2026, 4, 1),
    );

DmMessageDto _msg(String id, String body, {required bool mine, String status = 'VISIBLE'}) =>
    DmMessageDto(
      id: id,
      channelId: 'c1',
      senderId: mine ? 'me' : 'u1',
      body: body,
      status: status,
      mine: mine,
      createdAt: DateTime(2026, 5, 1),
    );

void main() {
  testWidgets('inbox renders channels with counterpart + scope chip', (tester) async {
    await tester.pumpWidget(_wrap(
      const DmInboxScreen(),
      _FakeDmRepo(channels: [_channel('c1', '하늘', unread: true)]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('하늘'), findsOneWidget);
    expect(find.text('모집'), findsOneWidget);
    expect(find.byKey(const Key('dm-channel-c1')), findsOneWidget);
  });

  testWidgets('inbox shows empty state when there are no channels', (tester) async {
    await tester.pumpWidget(_wrap(const DmInboxScreen(), _FakeDmRepo()));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 주고받은 메시지가 없어요'), findsOneWidget);
  });

  testWidgets('thread renders messages and shows the composer when OPEN', (tester) async {
    await tester.pumpWidget(_wrap(
      const DmThreadScreen(channelId: 'c1', peerName: '하늘'),
      _FakeDmRepo(messages: [_msg('m1', '안녕하세요', mine: false), _msg('m2', '반가워요', mine: true)]),
    ));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요'), findsOneWidget);
    expect(find.text('반가워요'), findsOneWidget);
    expect(find.byKey(const Key('dm-send-button')), findsOneWidget);
  });

  testWidgets('CLOSED channel hides the composer and shows the banner', (tester) async {
    await tester.pumpWidget(_wrap(
      const DmThreadScreen(channelId: 'c1'),
      _FakeDmRepo(messages: [_msg('m1', '마지막', mine: false)], channelStatus: 'CLOSED'),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-send-button')), findsNothing);
    expect(find.textContaining('종료된 대화'), findsOneWidget);
  });

  testWidgets('a hidden message renders as a placeholder, not its body', (tester) async {
    await tester.pumpWidget(_wrap(
      const DmThreadScreen(channelId: 'c1'),
      _FakeDmRepo(messages: [_msg('m1', 'spam-body', mine: false, status: 'HIDDEN')]),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('숨김 처리된 메시지'), findsOneWidget);
    expect(find.text('spam-body'), findsNothing);
  });
}
