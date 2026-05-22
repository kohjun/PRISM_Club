import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/user_profile/data/user_profile_dto.dart';
import 'package:mobile/features/user_profile/data/user_profile_repository.dart';
import 'package:mobile/features/user_profile/ui/profile_activity_screen.dart';

PostDto _post(String id) => PostDto(
      id: id,
      roomId: 'r1',
      roomSlug: 'dating-event-reviews',
      roomName: '소개팅/매칭 이벤트 후기',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: '하늘', avatarUrl: null),
      body: '활동 항목 $id',
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      attachments: const [],
      replyCount: 0,
      likeCount: 0,
      likedByMe: false,
    );

class _FakeProfileRepo implements UserProfileRepository {
  _FakeProfileRepo({required this.pages});

  /// List of pages the fake serves, in order. Each call to `getActivity`
  /// returns the next page until the list is exhausted.
  final List<ProfileActivityPage> pages;
  int _calls = 0;

  @override
  Future<UserProfileBundleDto> getProfile(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileSubDto> updateMyProfile(UpdateProfileInput input) {
    throw UnimplementedError();
  }

  @override
  Future<ProfileActivityPage> getActivity(
    String userId, {
    String? cursor,
    int limit = 20,
  }) async {
    final i = _calls.clamp(0, pages.length - 1);
    _calls += 1;
    return pages[i];
  }

  int get calls => _calls;
}

Widget _wrap(_FakeProfileRepo repo) => ProviderScope(
      overrides: [
        userProfileRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: ProfileActivityScreen(userId: 'u-haneul', title: '활동'),
      ),
    );

void main() {
  testWidgets('renders first page items from the repository',
      (tester) async {
    final repo = _FakeProfileRepo(pages: [
      ProfileActivityPage(
        items: [_post('p-1'), _post('p-2')],
        nextCursor: null,
      ),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('활동 항목 p-1'), findsOneWidget);
    expect(find.textContaining('활동 항목 p-2'), findsOneWidget);
    expect(repo.calls, 1);
  });

  testWidgets('empty page shows the EmptyView copy', (tester) async {
    final repo = _FakeProfileRepo(pages: [
      const ProfileActivityPage(items: [], nextCursor: null),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('아직 활동이 없어요'), findsOneWidget);
  });

  testWidgets(
      'scrolling toward the bottom requests the next page from the repo',
      (tester) async {
    // First page has 20 items + a non-null cursor so the screen knows
    // there's more. Second page is the tail.
    final firstItems = List.generate(20, (i) => _post('p-$i'));
    final repo = _FakeProfileRepo(pages: [
      ProfileActivityPage(items: firstItems, nextCursor: 'cursor-1'),
      ProfileActivityPage(
        items: [_post('p-tail')],
        nextCursor: null,
      ),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, 1);

    // Scroll to the bottom of the list — the screen's listener should
    // pull the next page.
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump();
    await tester.pump();
    // The async load fires; give it a chance to resolve.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(repo.calls, greaterThanOrEqualTo(2));
    expect(find.textContaining('활동 항목 p-tail'), findsOneWidget);
  });
}
