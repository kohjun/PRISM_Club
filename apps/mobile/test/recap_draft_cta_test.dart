import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_error.dart';
import 'package:mobile/features/event_detail/data/recap_suggest_dto.dart';
import 'package:mobile/features/event_detail/data/recap_suggest_repository.dart';
import 'package:mobile/features/event_detail/ui/widgets/recap_draft_cta.dart';

class _FakeRecapRepository extends RecapSuggestRepository {
  _FakeRecapRepository(
    super.ref, {
    this.suggestion,
    this.error,
    this.completer,
  });

  final RecapSuggestionDto? suggestion;
  final ApiError? error;
  // When non-null the suggest() future awaits this completer before
  // settling — used by the loading-state test to hold the UI mid-flight.
  final Completer<RecapSuggestionDto>? completer;

  @override
  Future<RecapSuggestionDto> suggest(String eventCardId) async {
    if (completer != null) return completer!.future;
    if (error != null) throw error!;
    if (suggestion != null) return suggestion!;
    throw StateError('fake repo not configured');
  }
}

RecapSuggestionDto _suggestion({
  List<String> rooms = const ['dating-event-reviews'],
}) => RecapSuggestionDto(
      event: const RecapEventDto(
        id: 'card-1',
        title: 'PRISM 소개팅 미션 나이트',
        startsAt: '2026-04-25T19:00:00Z',
        venueName: '홍대 스튜디오',
        region: '서울/홍대',
      ),
      suggestedBody: '## PRISM 소개팅 미션 나이트 후기\n\n참석자 3명',
      suggestedAttachments: const [
        RecapAttachmentDto(
          attachmentType: 'EVENT_CARD',
          targetId: 'card-1',
        ),
      ],
      suggestedRoomSlugs: rooms,
    );

Widget _wrap(
  Widget child, {
  RecapSuggestionDto? suggestion,
  ApiError? error,
  Completer<RecapSuggestionDto>? completer,
}) =>
    ProviderScope(
      overrides: [
        recapSuggestRepositoryProvider.overrideWith(
          (ref) => _FakeRecapRepository(
            ref,
            suggestion: suggestion,
            error: error,
            completer: completer,
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('hides itself for UPCOMING events', (tester) async {
    await tester.pumpWidget(_wrap(
      const RecapDraftCallToAction(
        eventCardId: 'card-1',
        eventStatus: 'UPCOMING',
      ),
    ));
    expect(find.byKey(const Key('recap-draft-cta')), findsNothing);
    expect(find.text('후기 초안 만들기'), findsNothing);
  });

  testWidgets('renders the CTA button for COMPLETED events',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const RecapDraftCallToAction(
        eventCardId: 'card-1',
        eventStatus: 'COMPLETED',
      ),
      suggestion: _suggestion(),
    ));
    expect(find.byKey(const Key('recap-draft-cta')), findsOneWidget);
    expect(find.text('후기 초안 만들기'), findsOneWidget);
  });

  testWidgets('403 surfaces the backend message in a snackbar',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const RecapDraftCallToAction(
        eventCardId: 'card-1',
        eventStatus: 'COMPLETED',
      ),
      error: ApiError(
        'FORBIDDEN',
        '이 이벤트의 후기 초안은 연결된 방의 운영자 또는 검증된 기획자만 만들 수 있어요.',
        403,
      ),
    ));
    await tester.tap(find.byKey(const Key('recap-draft-cta')));
    await tester.pump(); // start loading
    await tester.pump(const Duration(milliseconds: 50)); // resolve future
    await tester.pump(); // surface snackbar

    expect(
      find.textContaining('운영자 또는 검증된 기획자'),
      findsOneWidget,
    );
  });

  testWidgets('button enters loading state on tap until response settles',
      (tester) async {
    // Use a completer to hold the suggest() future mid-flight so the
    // loading UI is observable. We never resolve it — the test only
    // cares about the in-flight state.
    final completer = Completer<RecapSuggestionDto>();
    await tester.pumpWidget(_wrap(
      const RecapDraftCallToAction(
        eventCardId: 'card-1',
        eventStatus: 'COMPLETED',
      ),
      completer: completer,
    ));
    await tester.tap(find.byKey(const Key('recap-draft-cta')));
    await tester.pump(); // run setState(_loading=true)
    expect(find.text('후기 초안 만드는 중…'), findsOneWidget);
    // Now complete so the test doesn't leak a pending future; we don't
    // exercise the post-success branch because it would require a
    // GoRouter to handle context.push.
    completer.complete(_suggestion(rooms: const []));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('empty room list surfaces a friendly snackbar',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const RecapDraftCallToAction(
        eventCardId: 'card-1',
        eventStatus: 'COMPLETED',
      ),
      suggestion: _suggestion(rooms: const []),
    ));
    await tester.tap(find.byKey(const Key('recap-draft-cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.textContaining('연결된 방을 찾지 못했어요'), findsOneWidget);
  });
}
