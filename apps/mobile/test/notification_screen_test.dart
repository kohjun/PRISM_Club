import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_provider.dart';
import 'package:mobile/features/notifications/data/notification_dto.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/ui/notification_screen.dart';

NotificationListDto _twoNotifs() => NotificationListDto(
      items: [
        NotificationDto(
          id: 'n1',
          type: 'REPLY_ON_POST',
          isRead: false,
          payload: {'postId': 'p1', 'authorNickname': 'joon'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        NotificationDto(
          id: 'n2',
          type: 'CONTRIBUTION_RESOLVED',
          isRead: true,
          payload: {
            'topicHubTitle': 'FAQ 허브',
            'decision': 'APPROVED',
            'spaceAccessPolicy': 'PUBLIC',
          },
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ],
      nextCursor: null,
      unreadCount: 1,
    );

Dio _dio({void Function(RequestOptions)? onRequest}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      onRequest?.call(options);
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'updated_count': 1},
        ),
      );
    },
  ));
  return dio;
}

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: NotificationScreen()),
    );

void main() {
  testWidgets('renders two tiles, unread dot on unread notification',
      (tester) async {
    await tester.pumpWidget(_wrap([
      notificationsProvider.overrideWith((_) async => _twoNotifs()),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('댓글을 남겼어요'), findsOneWidget);
    expect(find.textContaining('제안이 APPROVED'), findsOneWidget);

    // n1 is unread → an unread dot (CircleAvatar with PrismColors.primary) is shown
    // _NotificationTile adds CircleAvatar only for unread items
    final dots = tester.widgetList<CircleAvatar>(find.byType(CircleAvatar));
    expect(dots.where((a) => a.radius == 4).length, 1);
  });

  testWidgets('shows EmptyView when notifications list is empty',
      (tester) async {
    final empty = NotificationListDto(
        items: const [], nextCursor: null, unreadCount: 0);
    await tester.pumpWidget(_wrap([
      notificationsProvider.overrideWith((_) async => empty),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('새 알림이 없어요'), findsOneWidget);
  });

  testWidgets('tap 모두 읽음 triggers provider refresh',
      (tester) async {
    var callCount = 0;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationsProvider.overrideWith((_) async {
          callCount++;
          // Second call (after invalidation) returns empty list
          if (callCount > 1) {
            return NotificationListDto(
                items: const [], nextCursor: null, unreadCount: 0);
          }
          return _twoNotifs();
        }),
        unreadCountProvider.overrideWith((_) async => 0),
        dioProvider.overrideWith((_) => _dio()),
      ],
      child: const MaterialApp(home: NotificationScreen()),
    ));
    await tester.pump();
    await tester.pump();

    // Initial render shows 2 notifications
    expect(find.textContaining('댓글을 남겼어요'), findsOneWidget);

    await tester.tap(find.text('모두 읽음'));
    // Allow the async markAllRead + invalidation chain to complete
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // After markAllRead invalidates the provider, it re-fetches and shows empty
    expect(find.text('새 알림이 없어요'), findsOneWidget);
  });
}
