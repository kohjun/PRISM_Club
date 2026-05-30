import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/me_dto.dart';
import 'package:mobile/features/notifications/data/notification_dto.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/post/data/recruitment_fields_dto.dart';

/// PR-C0 — pins the CURRENT fromJson behavior of the trickiest DTOs
/// before the json_helpers refactor (PR-C1). These tests must keep
/// passing UNCHANGED after the helper swap; that is what proves the
/// refactor is behavior-preserving. There were ZERO fromJson unit
/// tests before this file.
void main() {
  group('PostDto.fromJson', () {
    Map<String, dynamic> fullJson() => {
          'id': 'p-1',
          'room': {'id': 'r-1', 'slug': 'dating-event-reviews', 'name': '후기 방'},
          'author': {'id': 'u-1', 'nickname': '민서', 'avatar_url': null},
          'body': '본문',
          'status': 'VISIBLE',
          'post_type': 'GENERAL',
          'created_at': '2026-05-18T10:00:00.000Z',
          'updated_at': '2026-05-18T11:00:00.000Z',
          'attachments': <dynamic>[],
          'counts': {'reply_count': 3, 'like_count': 9, 'boost_count': 2},
          'liked_by_me': true,
          'boosted_by_me': true,
          'reply_policy': 'FOLLOWERS',
        };

    test('reads nested room + counts + top-level flags', () {
      final p = PostDto.fromJson(fullJson());
      expect(p.id, 'p-1');
      expect(p.roomSlug, 'dating-event-reviews');
      expect(p.author.nickname, '민서');
      // counts is a NESTED object; like/reply/boost come from inside it.
      expect(p.replyCount, 3);
      expect(p.likeCount, 9);
      expect(p.boostCount, 2);
      // liked_by_me / boosted_by_me are TOP-LEVEL, not under counts.
      expect(p.likedByMe, true);
      expect(p.boostedByMe, true);
      expect(p.replyPolicy, 'FOLLOWERS');
      expect(p.createdAt.isAtSameMomentAs(DateTime.parse('2026-05-18T10:00:00.000Z')), true);
    });

    test('defaults: missing counts → 0, missing optionals → null/defaults', () {
      final json = fullJson()
        ..remove('counts')
        ..remove('liked_by_me')
        ..remove('boosted_by_me')
        ..remove('status')
        ..remove('post_type')
        ..remove('reply_policy');
      final p = PostDto.fromJson(json);
      expect(p.replyCount, 0);
      expect(p.likeCount, 0);
      expect(p.boostCount, 0);
      expect(p.likedByMe, false);
      expect(p.boostedByMe, false);
      expect(p.status, 'VISIBLE');
      expect(p.postType, 'GENERAL');
      expect(p.replyPolicy, 'ANYONE');
      expect(p.recruitmentFields, isNull);
      expect(p.quotedPost, isNull);
      expect(p.poll, isNull);
      expect(p.myReaction, isNull);
    });

    test('parses optional poll + quoted_post + recruitment_fields when present', () {
      final json = fullJson()
        ..['post_type'] = 'RECRUITMENT'
        ..['recruitment_fields'] = {
          'role': '진행',
          'capacity': 3,
          'status': 'OPEN',
        }
        ..['quoted_post'] = {
          'id': 'q-1',
          'body_preview': '인용 미리보기',
          'author_nickname': '코랄',
          'room_slug': 'x',
        }
        ..['poll'] = {
          'id': 'poll-1',
          'question': '언제?',
          'options': [
            {'id': 'o-1', 'label': '토요일'},
          ],
        };
      final p = PostDto.fromJson(json);
      expect(p.isRecruitment, true);
      expect(p.recruitmentFields?.role, '진행');
      expect(p.quotedPost?.authorNickname, '코랄');
      expect(p.poll?.question, '언제?');
      expect(p.poll?.options.single.label, '토요일');
    });
  });

  group('RecruitmentFieldsDto.fromJson capacity coercion', () {
    RecruitmentFieldsDto parse(Object? capacity) =>
        RecruitmentFieldsDto.fromJson({
          'role': 'r',
          'capacity': capacity,
          'status': 'OPEN',
        });

    test('int stays int', () => expect(parse(5).capacity, 5));
    test('num (double) floors via toInt', () => expect(parse(3.0).capacity, 3));
    test('numeric string parses', () => expect(parse('7').capacity, 7));
    test('null → 0', () => expect(parse(null).capacity, 0));
    test('non-numeric string → 0', () => expect(parse('abc').capacity, 0));
    test('missing scalars default to empty + status OPEN', () {
      final r = RecruitmentFieldsDto.fromJson({});
      expect(r.role, '');
      expect(r.schedule, '');
      expect(r.status, 'OPEN');
      expect(r.capacity, 0);
    });
  });

  group('NotificationDto.fromJson', () {
    test('updated_at present → parsed independently of created_at', () {
      final n = NotificationDto.fromJson({
        'id': 'n-1',
        'type': 'REPLY_ON_POST',
        'created_at': '2026-05-18T10:00:00.000Z',
        'updated_at': '2026-05-18T12:00:00.000Z',
      });
      expect(n.createdAt.hour, isNot(n.updatedAt.hour));
      expect(n.isRead, false);
      expect(n.payload, isEmpty);
    });

    test('updated_at MISSING → defaults to created_at', () {
      final n = NotificationDto.fromJson({
        'id': 'n-2',
        'type': 'LIKE',
        'created_at': '2026-05-18T10:00:00.000Z',
      });
      expect(n.updatedAt.isAtSameMomentAs(n.createdAt), true);
    });

    test('actorCount reflects grouped actors + overflow', () {
      final n = NotificationDto.fromJson({
        'id': 'n-3',
        'type': 'LIKE',
        'created_at': '2026-05-18T10:00:00.000Z',
        'payload': {
          'actors': ['a', 'b', 'c'],
          'actors_overflow': 4,
        },
      });
      expect(n.actorCount, 7); // 3 listed + 4 overflow
      expect(n.isGrouped, true);
    });
  });

  group('PostAttachmentDto.fromJson type branching', () {
    test('EVENT_CARD target resolves to asEventCard', () {
      final a = PostAttachmentDto.fromJson({
        'id': 'a-1',
        'attachment_type': 'EVENT_CARD',
        'sort_order': 2,
        'target': {
          'id': 'e-1',
          'external_event_id': 'evt-1',
          'title': '이벤트',
          'venue_name': '홍대',
          'region': '서울',
          'starts_at': '2026-06-01T19:00:00.000Z',
          'event_status': 'UPCOMING',
          'thumbnail_url': null,
        },
      });
      expect(a.sortOrder, 2);
      expect(a.asEventCard, isNotNull);
      expect(a.asReference, isNull);
      expect(a.asImage, isNull);
    });

    test('REFERENCE target resolves to asReference; sort_order defaults 0', () {
      final a = PostAttachmentDto.fromJson({
        'id': 'a-2',
        'attachment_type': 'REFERENCE',
        'target': {
          'id': 'ref-1',
          'type': 'TV_SHOW',
          'url': 'https://example.com',
          'title': '레퍼런스',
        },
      });
      expect(a.sortOrder, 0);
      expect(a.asReference, isNotNull);
      expect(a.asEventCard, isNull);
    });
  });

  group('PollDto.fromJson', () {
    test('expires_at present parses; options + my votes hydrate', () {
      final p = PollDto.fromJson({
        'id': 'poll-1',
        'question': '선호 시간?',
        'expires_at': '2026-06-01T00:00:00.000Z',
        'allow_multiple': true,
        'status': 'OPEN',
        'options': [
          {'id': 'o-1', 'label': '오전', 'vote_count': 4},
          {'id': 'o-2', 'label': '오후', 'vote_count': 9},
        ],
        'total_votes': 13,
        'my_vote_option_ids': ['o-2'],
      });
      expect(p.expiresAt, isNotNull);
      expect(p.allowMultiple, true);
      expect(p.options.length, 2);
      expect(p.options[1].voteCount, 9);
      expect(p.totalVotes, 13);
      expect(p.hasVotedFor('o-2'), true);
      expect(p.hasVotedFor('o-1'), false);
    });

    test('defaults: no expires_at / no options / allow_multiple false', () {
      final p = PollDto.fromJson({'id': 'poll-2', 'question': 'Q'});
      expect(p.expiresAt, isNull);
      expect(p.allowMultiple, false);
      expect(p.status, 'OPEN');
      expect(p.options, isEmpty);
      expect(p.totalVotes, 0);
      expect(p.myVoteOptionIds, isEmpty);
    });
  });

  group('MeDto.fromJson', () {
    test('status defaults to ACTIVE; roles hydrate; role getters', () {
      final m = MeDto.fromJson({
        'id': 'u-1',
        'nickname': '민서',
        'roles': ['VERIFIED_PLANNER', 'CURATOR'],
      });
      expect(m.status, 'ACTIVE');
      expect(m.roles, containsAll(['VERIFIED_PLANNER', 'CURATOR']));
      expect(m.isPlanner, true);
      expect(m.isCurator, true);
      expect(m.isModerator, false);
    });

    test('missing roles → empty list; nullable fields stay null', () {
      final m = MeDto.fromJson({'id': 'u-2'});
      expect(m.roles, isEmpty);
      expect(m.nickname, isNull);
      expect(m.region, isNull);
      expect(m.isPlanner, false);
    });
  });
}
