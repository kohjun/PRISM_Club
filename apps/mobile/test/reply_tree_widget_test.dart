import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/post/data/reply_dto.dart';
import 'package:mobile/widgets/reply_tree_widget.dart';

ReplyDto _reply({
  required String id,
  String? parent,
  String body = 'r',
  String nickname = 'u',
}) =>
    ReplyDto(
      id: id,
      postId: 'p1',
      parentReplyId: parent,
      author: PostAuthorDto(id: nickname, nickname: nickname, avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      createdAt: DateTime(2026, 5, 16),
      updatedAt: DateTime(2026, 5, 16),
      likeCount: 0,
      likedByMe: false,
    );

void main() {
  testWidgets('ReplyTreeWidget groups depth-2 replies under their parent',
      (tester) async {
    final replies = [
      _reply(id: 'r1', body: 'top from joon', nickname: 'joon'),
      _reply(
        id: 'r1a',
        parent: 'r1',
        body: 'child from minseo',
        nickname: 'minseo',
      ),
      _reply(id: 'r2', body: 'top from haneul', nickname: 'haneul'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReplyTreeWidget(
          replies: replies,
          onReply: (_) {},
          onLike: (_) {},
        ),
      ),
    ));

    expect(find.text('top from joon'), findsOneWidget);
    expect(find.text('child from minseo'), findsOneWidget);
    expect(find.text('top from haneul'), findsOneWidget);

    // Child reply shows the indent arrow icon
    expect(find.byIcon(Icons.subdirectory_arrow_right), findsOneWidget);
  });

  testWidgets('ReplyTreeWidget shows empty state when no replies',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReplyTreeWidget(
          replies: const [],
          onReply: (_) {},
          onLike: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('첫 댓글'), findsOneWidget);
  });
}
