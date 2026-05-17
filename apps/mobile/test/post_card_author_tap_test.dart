import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/widgets/post_card_widget.dart';

PostDto _post() => PostDto(
      id: 'p1',
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(
          id: 'u-minseo', nickname: 'minseo', avatarUrl: null),
      body: '게시글 본문',
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      attachments: const [],
      replyCount: 0,
      likeCount: 0,
      likedByMe: false,
    );

void main() {
  testWidgets('tapping author area fires onAuthorTap(authorId)',
      (tester) async {
    String? tappedId;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCardWidget(
          post: _post(),
          onAuthorTap: (id) => tappedId = id,
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('minseo'), findsOneWidget);

    // Tap on the author nickname text — its parent InkWell handles the gesture.
    await tester.tap(find.text('minseo'));
    await tester.pump();

    expect(tappedId, 'u-minseo');
  });
}
