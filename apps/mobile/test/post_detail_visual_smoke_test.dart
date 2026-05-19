import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/post/data/post_repository.dart';
import 'package:mobile/features/post/data/reply_dto.dart';
import 'package:mobile/features/post/data/reply_repository.dart';
import 'package:mobile/features/post/ui/post_detail_screen.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart';

import 'helpers/visual_smoke.dart';

PostDto _post(String id, String body) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '소개팅·매칭 이벤트 후기',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: '하늘 매우 긴 닉네임 후보', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
      attachments: const [],
      replyCount: 3,
      likeCount: 21,
      likedByMe: false,
    );

ReplyDto _reply(String id, String body) => ReplyDto(
      id: id,
      postId: 'p-1',
      parentReplyId: null,
      author: const PostAuthorDto(
          id: 'u-other', nickname: '다른 사람', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      createdAt: DateTime(2026, 5, 18, 10),
      updatedAt: DateTime(2026, 5, 18, 10),
      likeCount: 2,
      likedByMe: false,
    );

class _FakePostRepository implements PostRepository {
  _FakePostRepository(this.post);
  final PostDto post;

  @override
  Future<PostDto> getById(String id) async => post;

  @override
  Future<TimelinePage> getTimeline(String roomSlug,
          {String? cursor, int? limit}) async =>
      const TimelinePage(items: [], nextCursor: null);

  @override
  Future<PostDto> create(
    String roomSlug, {
    required String body,
    String postType = 'GENERAL',
    CreateRecruitmentFields? recruitmentFields,
    List<CreatePostAttachment> attachments = const [],
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();

  @override
  Future<PostDto> setRecruitmentStatus(String postId, String status) async =>
      throw UnimplementedError();
}

class _FakeReplyRepository implements ReplyRepository {
  _FakeReplyRepository(this.replies);
  final List<ReplyDto> replies;

  @override
  Future<List<ReplyDto>> listByPost(String postId) async => replies;

  @override
  Future<ReplyDto> create(
    String postId, {
    required String body,
    String? parentReplyId,
  }) async =>
      throw UnimplementedError();
}

Widget _wrap() {
  final post = _post('p-1',
      '본문이 매우 긴 게시글입니다. 좁은 360dp 폭에서도 본문이 깔끔히 흐르고, '
      '액션 행과 답글 컴포저가 겹치지 않아야 합니다. 한국어 줄바꿈 특성상 line break가 '
      '예측하기 어려운 점도 고려해야 합니다.');
  return ProviderScope(
    overrides: [
      postRepositoryProvider.overrideWithValue(_FakePostRepository(post)),
      replyRepositoryProvider.overrideWithValue(
        _FakeReplyRepository([
          _reply('r-1', '답글 본문이 좀 길어도 트리에서 안전.'),
        ]),
      ),
      // SaveNotifier reads savedItemsProvider('POST') in its build();
      // an empty list resolves the chain without real Dio.
      savedItemsProvider('POST').overrideWith(
        (_) async => const SavedItemListDto(items: []),
      ),
    ],
    child: const MaterialApp(home: PostDetailScreen(postId: 'p-1')),
  );
}

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'post detail visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // Post body fragment present.
      expect(find.textContaining('본문이 매우 긴'), findsOneWidget);
      // Reply composer placeholder.
      expect(find.textContaining('답글'), findsAtLeastNWidgets(1));
    });
  }
}
