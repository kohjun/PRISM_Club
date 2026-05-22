import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dio_provider.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart'
    show
        SavedItemsFilter,
        filteredSavedItemsProvider,
        savedCollectionsProvider,
        savedItemsProvider;
import 'package:mobile/features/saves/ui/saved_items_screen.dart';

PostDto _post(String id) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(
          id: 'u1', nickname: 'minseo', avatarUrl: null),
      body: '테스트 게시글 $id',
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      attachments: const [],
      replyCount: 0,
      likeCount: 0,
      likedByMe: false,
    );

ReferenceDto _ref(String id) => ReferenceDto(
      id: id,
      type: 'LINK',
      url: 'https://example.com/$id',
      title: '레퍼런스 $id',
      sourceName: null,
      thumbnailUrl: null,
      summary: null,
      status: 'VISIBLE',
      sourceTier: 'UNKNOWN',
    );

SavedItemListDto _mixedList() => SavedItemListDto(
      items: [
        SavedItemDto(
          id: 's1',
          targetType: 'POST',
          targetId: 'post-1',
          savedAt: DateTime(2025),
          postTarget: _post('post-1'),
        ),
        SavedItemDto(
          id: 's2',
          targetType: 'REFERENCE',
          targetId: 'ref-1',
          savedAt: DateTime(2025),
          referenceTarget: _ref('ref-1'),
        ),
      ],
    );

SavedItemListDto _postOnlyList() => SavedItemListDto(
      items: [
        SavedItemDto(
          id: 's1',
          targetType: 'POST',
          targetId: 'post-1',
          savedAt: DateTime(2025),
          postTarget: _post('post-1'),
        ),
      ],
    );

Dio _fakeDio({void Function(RequestOptions)? onPost}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.method == 'POST') onPost?.call(options);
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {'saved': false},
        ),
      );
    },
  ));
  return dio;
}

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: SavedItemsScreen()),
    );

void main() {
  testWidgets('shows 1 post + 1 reference; 글 chip filters to post only',
      (tester) async {
    await tester.pumpWidget(_wrap([
      savedCollectionsProvider.overrideWith((_) async => const []),
      filteredSavedItemsProvider(const SavedItemsFilter())
          .overrideWith((_) async => _mixedList()),
      filteredSavedItemsProvider(const SavedItemsFilter(type: 'POST'))
          .overrideWith((_) async => _postOnlyList()),
      filteredSavedItemsProvider(const SavedItemsFilter(type: 'REFERENCE'))
          .overrideWith((_) async => SavedItemListDto(items: const [])),
      filteredSavedItemsProvider(const SavedItemsFilter(type: 'EVENT_CARD'))
          .overrideWith((_) async => SavedItemListDto(items: const [])),
      // Legacy provider that the unsave handler also invalidates.
      savedItemsProvider(null)
          .overrideWith((_) async => SavedItemListDto(items: const [])),
    ]));
    await tester.pump();
    await tester.pump();

    // Both items visible (all-types view)
    expect(find.textContaining('테스트 게시글 post-1'), findsOneWidget);
    expect(find.text('레퍼런스 ref-1'), findsOneWidget);

    // Tap the 글 chip to filter to POST only
    await tester.tap(find.text('글'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('테스트 게시글 post-1'), findsOneWidget);
    expect(find.text('레퍼런스 ref-1'), findsNothing);
  });

  testWidgets('unsave button tap fires toggleSave via repository',
      (tester) async {
    String? togglePath;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        savedCollectionsProvider.overrideWith((_) async => const []),
        filteredSavedItemsProvider(const SavedItemsFilter())
            .overrideWith((_) async => _mixedList()),
        filteredSavedItemsProvider(const SavedItemsFilter(type: 'POST'))
            .overrideWith((_) async => SavedItemListDto(items: const [])),
        filteredSavedItemsProvider(const SavedItemsFilter(type: 'REFERENCE'))
            .overrideWith((_) async => SavedItemListDto(items: const [])),
        filteredSavedItemsProvider(const SavedItemsFilter(type: 'EVENT_CARD'))
            .overrideWith((_) async => SavedItemListDto(items: const [])),
        savedItemsProvider(null)
            .overrideWith((_) async => SavedItemListDto(items: const [])),
        dioProvider.overrideWith((_) => _fakeDio(
              onPost: (opts) => togglePath = opts.path,
            )),
      ],
      child: const MaterialApp(home: SavedItemsScreen()),
    ));
    await tester.pump();
    await tester.pump();

    // Tap the first bookmark icon (POST item unsave)
    final bookmarkIcons = find.byIcon(Icons.bookmark);
    expect(bookmarkIcons, findsAtLeastNWidgets(1));
    await tester.runAsync(() async {
      await tester.tap(bookmarkIcons.first);
      // Allow the async toggle → Dio post → interceptor chain to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(togglePath, '/me/saves');
  });
}
