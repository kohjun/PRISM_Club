import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/features/room/data/room_summary_dto.dart';
import 'package:mobile/features/search/data/search_repository.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_dto.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_repository.dart';
import 'package:mobile/features/topic_hub/ui/topic_hub_screen.dart';

import 'helpers/visual_smoke.dart';

KnowledgeBlockDto _block(String id, String blockType, String title, String body) =>
    KnowledgeBlockDto(
      id: id,
      blockType: blockType,
      title: title,
      body: body,
      sortOrder: 0,
    );

TopicSignalDto _signal(String id, String type, String title, String value) =>
    TopicSignalDto(
      id: id,
      signalType: type,
      title: title,
      payload: {'text': value},
    );

TopicHubBundle _populatedBundle() => TopicHubBundle(
      categorySlug: 'love-content',
      categoryName: '연애 예능',
      categoryDescription: '소개팅·매칭·환승연애 등 연애 콘텐츠 — 좁은 폭에서 잘려도 깨지지 않아야 함',
      hubTitle: '연애 예능 토픽 허브',
      hubSummary:
          '핵심 정보, 추천 이벤트, 레퍼런스, 그리고 활발한 방을 한곳에 모았어요. 본문이 길어도 360dp에서 overflow 없이 렌더링되어야 합니다.',
      blocks: [
        _block('b1', 'OVERVIEW', '개요',
            '연애 예능은 한국 콘텐츠의 대표 장르. 본문이 매우 길어서 카드 폭을 검증합니다.'),
        _block('b2', 'POPULAR_FORMAT', '인기 포맷', '환승연애식 토크, 비밀 카드 미션.'),
        _block('b3', 'RECOMMENDED_PARTY_SIZE', '추천 인원', '4–8명 권장.'),
      ],
      signals: [
        _signal('s1', 'POPULARITY', '인기 지수', '높음'),
        _signal('s2', 'TREND', '이번 주 트렌드', '환승연애 시즌2 — 긴 텍스트도 안전'),
      ],
      relatedEvents: [
        EventCardDto(
          id: 'card-1',
          externalEventId: 'evt-001',
          title: 'PRISM 소개팅 미션 나이트 — 매우 긴 제목이 들어가도 hero card는 무너지지 않아야 함',
          venueName: '홍대 스튜디오',
          region: '서울/홍대',
          startsAt: DateTime(2026, 5, 25, 19),
          eventStatus: 'OPEN',
          thumbnailUrl: null,
        ),
      ],
      relatedReferences: const [
        ReferenceDto(
          id: 'ref-1',
          type: 'TV_SHOW',
          url: 'https://example.com/show',
          title: '환승연애 시즌2 — 레퍼런스 카드 제목이 매우 길어도 두 줄 ellipsis',
          sourceName: 'tvN',
          thumbnailUrl: null,
          summary: '본문 요약이 길게 들어와도 카드 폭을 넘기지 않습니다.',
          status: 'VISIBLE',
        ),
      ],
      rooms: const [
        RoomSummaryDto(
          id: 'room-1',
          slug: 'dating-event-reviews',
          name: '소개팅·매칭 이벤트 후기 — 길어도 안전',
          description: '오프라인 매칭 이벤트 후기와 운영 노트를 나누는 방.',
          origin: 'OFFICIAL',
          roomType: 'EVENT_REACTION',
          ownerNickname: null,
        ),
      ],
    );

Widget _wrap(TopicHubBundle bundle) => ProviderScope(
      overrides: [
        topicHubProvider('love-content').overrideWith((_) async => bundle),
        // searchSuggestionsProvider is read inside the data-state body
        // for the chip row; empty list is fine and avoids real Dio.
        searchSuggestionsProvider('love-content')
            .overrideWith((_) async => const <String>[]),
      ],
      child: const MaterialApp(
        home: TopicHubScreen(categorySlug: 'love-content'),
      ),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'topic hub visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      // expectNoOverflowWhileScrolling drags the CustomScrollView past
      // every sliver — hero, knowledge blocks, signals, related events,
      // references, rooms — so overflow in lower sections is exercised,
      // not just the initial viewport.
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap(_populatedBundle()));
        await tester.pump();
        await tester.pump();
      });

      // Hub title is the most stable visible anchor (set on hub, not
      // category). Confirms the data-state body rendered.
      expect(find.text('연애 예능 토픽 허브'), findsAtLeastNWidgets(1));
    });
  }
}
