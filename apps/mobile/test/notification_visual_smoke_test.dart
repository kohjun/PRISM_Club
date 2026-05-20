import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/notification_dto.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/ui/notification_screen.dart';

import 'helpers/visual_smoke.dart';

NotificationDto _notif(
  String id,
  String type, {
  required Map<String, dynamic> payload,
  bool isRead = false,
}) =>
    NotificationDto(
      id: id,
      type: type,
      isRead: isRead,
      payload: payload,
      createdAt: DateTime(2026, 5, 18, 10),
    );

NotificationListDto _list() => NotificationListDto(
      items: [
        _notif('n1', 'REPLY_ON_POST', payload: {
          'authorNickname': '하늘 매우 긴 닉네임 후보',
          'bodyPreview': '답글 미리보기가 좀 길어도 한 줄 ellipsis로 안전해야 합니다.',
        }),
        _notif('n2', 'CONTRIBUTION_RESOLVED',
            isRead: true,
            payload: {
              'topicHubTitle': '연애 예능과 매칭',
              'decision': 'APPROVED',
            }),
        _notif('n3', 'NEW_POST_IN_FOLLOWED_ROOM', payload: {
          'roomName': '소개팅·매칭 이벤트 후기 — 긴 방 이름',
        }),
      ],
      nextCursor: null,
      unreadCount: 2,
    );

Widget _wrap() => ProviderScope(
      overrides: [
        notificationsProvider.overrideWith((_) async => _list()),
      ],
      child: const MaterialApp(home: NotificationScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'notification visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // AppBar title + at least one notification row visible.
      expect(find.text('알림'), findsOneWidget);
      expect(find.textContaining('하늘 매우 긴'), findsOneWidget);
    });
  }
}
