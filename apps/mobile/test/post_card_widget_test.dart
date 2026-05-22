import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/widgets/post_card_widget.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

PostDto _post({
  String body = '본문',
  List<PostAttachmentDto> attachments = const [],
  int likeCount = 0,
  int replyCount = 0,
  bool likedByMe = false,
  QuotedPostRefDto? quotedPost,
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
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      updatedAt: DateTime.now(),
      attachments: attachments,
      likeCount: likeCount,
      replyCount: replyCount,
      likedByMe: likedByMe,
      quotedPost: quotedPost,
    );

void main() {
  testWidgets('PostCardWidget renders body, author, and counters',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PostCardWidget(
          post: _post(body: 'hello world', likeCount: 3, replyCount: 5)),
    ));
    // Body now lives inside a RichText (mention-aware), so the plain
    // Text-finder doesn't see it. Use the richer textContaining matcher.
    expect(find.textContaining('hello world'), findsOneWidget);
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
      sourceTier: 'UNKNOWN',
    );
    await tester.pumpWidget(_wrap(
      PostCardWidget(
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
    ));
    expect(find.text('PRISM 소개팅 미션 나이트'), findsOneWidget);
    expect(find.text('환승연애 대화 구조 분석'), findsOneWidget);
  });

  testWidgets('PostCardWidget shows filled heart when likedByMe', (tester) async {
    await tester.pumpWidget(_wrap(
      PostCardWidget(post: _post(likedByMe: true)),
    ));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets(
      'PostCardWidget renders QuotedBlock with preview and author handle',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PostCardWidget(
        post: _post(
          body: '내 의견은',
          quotedPost: const QuotedPostRefDto(
            id: 'orig-1',
            bodyPreview: '원본 게시글 일부 미리보기',
            authorNickname: '하늘',
            roomSlug: 'dating-event-reviews',
            available: true,
          ),
        ),
      ),
    ));
    expect(find.text('원본 게시글 일부 미리보기'), findsOneWidget);
    expect(find.textContaining('@하늘'), findsOneWidget);
    expect(find.textContaining('#dating-event-reviews'), findsOneWidget);
    // Deleted-sentinel copy should NOT appear in the available case.
    expect(find.text('삭제된 글입니다'), findsNothing);
  });

  testWidgets(
      'PostCardWidget renders deleted-sentinel when quotedPost.available=false',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PostCardWidget(
        post: _post(
          quotedPost: const QuotedPostRefDto(
            id: '',
            bodyPreview: '',
            authorNickname: '',
            roomSlug: '',
            available: false,
          ),
        ),
      ),
    ));
    expect(find.text('삭제된 글입니다'), findsOneWidget);
  });
}
