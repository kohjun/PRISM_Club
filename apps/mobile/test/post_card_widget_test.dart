import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/widgets/post_card_widget.dart';

PostDto _post({
  String body = '본문',
  List<PostAttachmentDto> attachments = const [],
  int likeCount = 0,
  int replyCount = 0,
  bool likedByMe = false,
}) =>
    PostDto(
      id: 'p1',
      roomId: 'r1',
      roomSlug: 'dating-event-reviews',
      roomName: '소개팅/매칭 이벤트 후기',
      author: const PostAuthorDto(
          id: 'u-minseo', nickname: '민서', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      updatedAt: DateTime.now(),
      attachments: attachments,
      likeCount: likeCount,
      replyCount: replyCount,
      likedByMe: likedByMe,
    );

void main() {
  testWidgets('PostCardWidget renders body, author, and counters',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCardWidget(
            post: _post(body: 'hello world', likeCount: 3, replyCount: 5)),
      ),
    ));
    expect(find.text('hello world'), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('PostCardWidget renders both attachment types', (tester) async {
    final eventCard = EventCardDto(
      id: 'e1',
      externalEventId: 'evt-001',
      title: 'PRISM 소개팅 미션 나이트',
      venueName: '홍대 스튜디오',
      region: '서울/홍대',
      startsAt: DateTime(2026, 4, 25, 19),
      eventStatus: 'COMPLETED',
      thumbnailUrl: null,
    );
    const reference = ReferenceDto(
      id: 'r1',
      type: 'TV_SHOW',
      url: 'https://example.com/r',
      title: '환승연애 대화 구조 분석',
      sourceName: '블로그',
      thumbnailUrl: null,
      summary: null,
      status: 'VISIBLE',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCardWidget(
          post: _post(attachments: [
            PostAttachmentDto(
                id: 'a1',
                attachmentType: 'EVENT_CARD',
                target: eventCard,
                sortOrder: 1),
            PostAttachmentDto(
                id: 'a2',
                attachmentType: 'REFERENCE',
                target: reference,
                sortOrder: 2),
          ]),
        ),
      ),
    ));
    expect(find.text('PRISM 소개팅 미션 나이트'), findsOneWidget);
    expect(find.text('환승연애 대화 구조 분석'), findsOneWidget);
  });

  testWidgets('PostCardWidget shows filled heart when likedByMe', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PostCardWidget(post: _post(likedByMe: true))),
    ));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}
