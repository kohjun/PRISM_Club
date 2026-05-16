/**
 * PRISM Club — milestones 1 + 2 + 4 seed.
 *
 * Milestone 1 (Love Content demo flow): 1 category + topic hub + knowledge
 * blocks + signals + event cards + references + rooms + posts + replies.
 *
 * Milestone 2: adds a 4th persona (`coral`) with CURATOR role, plus three
 * sample contributions (2 pending + 1 approved with snapshot) so the
 * curation queue and the audit trail render with data.
 *
 * Milestone 4: activates the planner space. Adds two VERIFIED_PLANNER personas
 * (`studio_lead`, `studio_mate`), sets the planner space access_policy to
 * PLANNER_ONLY, and seeds a planner category + topic hub + 1 RECRUITMENT room
 * with 3 sample recruitment posts (2 OPEN, 1 CLOSED).
 *
 * Re-runnable: clearAll truncates everything; UUIDs are fixed.
 */

import { PrismaClient } from '@prisma/client';

// -- Fixed UUIDs ------------------------------------------------------------

export const U = {
  user: {
    minseo: '11111111-1111-1111-1111-111111111111',
    joon: '22222222-2222-2222-2222-222222222222',
    haneul: '33333333-3333-3333-3333-333333333333',
    coral: '44444444-4444-4444-4444-444444444444', // CURATOR — milestone 2
    studio_lead: '55555555-5555-5555-5555-555555555555', // VERIFIED_PLANNER — milestone 4
    studio_mate: '66666666-6666-6666-6666-666666666666', // VERIFIED_PLANNER — milestone 4
  },
  space: {
    participant: 'aa000000-0000-0000-0000-000000000001',
    planner: 'aa000000-0000-0000-0000-000000000002',
  },
  category: {
    loveContent: 'bb000000-0000-0000-0000-000000000001',
    plannerStaff: 'bb000000-0000-0000-0000-000000000002', // milestone 4
  },
  topicHub: {
    loveContent: 'cc000000-0000-0000-0000-000000000001',
    plannerStaff: 'cc000000-0000-0000-0000-000000000002', // milestone 4
  },
  block: {
    overview: 'cc100000-0000-0000-0000-000000000001',
    popularFormat: 'cc100000-0000-0000-0000-000000000002',
    partySize: 'cc100000-0000-0000-0000-000000000003',
    moodTips: 'cc100000-0000-0000-0000-000000000004',
    faq: 'cc100000-0000-0000-0000-000000000005',
    warning: 'cc100000-0000-0000-0000-000000000006',
    plannerOverview: 'cc100000-0000-0000-0000-000000000101', // milestone 4
    plannerFaq: 'cc100000-0000-0000-0000-000000000102', // milestone 4
    plannerChecklist: 'cc100000-0000-0000-0000-000000000103', // milestone 4
  },
  signal: {
    popularRef: 'cc200000-0000-0000-0000-000000000001',
    hotDebate: 'cc200000-0000-0000-0000-000000000002',
    verifiedReviews: 'cc200000-0000-0000-0000-000000000003',
  },
  event: {
    e001: 'dd000000-0000-0000-0000-000000000001',
    e002: 'dd000000-0000-0000-0000-000000000002',
    e003: 'dd000000-0000-0000-0000-000000000003',
  },
  reference: {
    swapTalkAnalysis: 'ee000000-0000-0000-0000-000000000001',
    selectRuleYoutube: 'ee000000-0000-0000-0000-000000000002',
    firstMeetingIdeas: 'ee000000-0000-0000-0000-000000000003',
  },
  room: {
    datingReviews: 'ff000000-0000-0000-0000-000000000001',
    loveShowRefs: 'ff000000-0000-0000-0000-000000000002',
    swapTalkGame: 'ff000000-0000-0000-0000-000000000003',
    plannerRecruitment: 'ff000000-0000-0000-0000-000000000004', // milestone 4
  },
  post: {
    minseoReview: '99000000-0000-0000-0000-000000000001',
    joonQuestion: '99000000-0000-0000-0000-000000000002',
    haneulIdea: '99000000-0000-0000-0000-000000000003',
    recruitDatingNight: '99000000-0000-0000-0000-000000000101', // milestone 4
    recruitTalkRound: '99000000-0000-0000-0000-000000000102', // milestone 4
    recruitClosed: '99000000-0000-0000-0000-000000000103', // milestone 4
  },
  contribution: {
    pendingMoodTipsEdit: 'a1000000-0000-0000-0000-000000000001',
    pendingNewChecklist: 'a1000000-0000-0000-0000-000000000002',
    approvedFaqEdit: 'a1000000-0000-0000-0000-000000000003',
  },
} as const;

// Dates relative to a fixed "today" for stable seeds.
const TODAY = new Date('2026-05-16T10:00:00Z');
const DAYS = (n: number): Date => new Date(TODAY.getTime() + n * 86_400_000);

// -- Helpers ----------------------------------------------------------------

async function clearAll(prisma: PrismaClient): Promise<void> {
  // Order matters: children before parents.
  await prisma.knowledgeContribution.deleteMany();
  await prisma.reaction.deleteMany();
  await prisma.postAttachment.deleteMany();
  await prisma.reply.deleteMany();
  await prisma.post.deleteMany();
  await prisma.roomPin.deleteMany();
  await prisma.room.deleteMany();
  await prisma.topicHubReferenceLink.deleteMany();
  await prisma.topicHubEventLink.deleteMany();
  await prisma.topicSignal.deleteMany();
  await prisma.knowledgeBlock.deleteMany();
  await prisma.topicHub.deleteMany();
  await prisma.reference.deleteMany();
  await prisma.eventCard.deleteMany();
  await prisma.category.deleteMany();
  await prisma.space.deleteMany();
  await prisma.userRole.deleteMany();
  await prisma.profile.deleteMany();
  await prisma.user.deleteMany();
}

async function seedUsers(prisma: PrismaClient): Promise<void> {
  await prisma.user.createMany({
    data: [
      { id: U.user.minseo, status: 'ACTIVE' },
      { id: U.user.joon, status: 'ACTIVE' },
      { id: U.user.haneul, status: 'ACTIVE' },
      { id: U.user.coral, status: 'ACTIVE' },
      { id: U.user.studio_lead, status: 'ACTIVE' },
      { id: U.user.studio_mate, status: 'ACTIVE' },
    ],
  });
  await prisma.profile.createMany({
    data: [
      { userId: U.user.minseo, nickname: '민서', region: '서울', interests: [] },
      { userId: U.user.joon, nickname: 'joon', region: '서울', interests: [] },
      { userId: U.user.haneul, nickname: 'haneul', region: '서울', interests: [] },
      { userId: U.user.coral, nickname: 'coral', region: '서울', interests: [] },
      { userId: U.user.studio_lead, nickname: 'studio_lead', region: '서울', interests: [] },
      { userId: U.user.studio_mate, nickname: 'studio_mate', region: '서울', interests: [] },
    ],
  });
  // Milestone 2: grant CURATOR role to coral. Others stay implicit MEMBER.
  await prisma.userRole.create({
    data: { userId: U.user.coral, role: 'CURATOR', source: 'seed' },
  });
  // Milestone 4: grant VERIFIED_PLANNER to the two studio personas.
  await prisma.userRole.createMany({
    data: [
      { userId: U.user.studio_lead, role: 'VERIFIED_PLANNER', source: 'seed' },
      { userId: U.user.studio_mate, role: 'VERIFIED_PLANNER', source: 'seed' },
    ],
  });
}

async function seedSpacesAndCategories(prisma: PrismaClient): Promise<void> {
  await prisma.space.createMany({
    data: [
      {
        id: U.space.participant,
        slug: 'participant',
        name: '참가자 커뮤니티',
        audience: 'PARTICIPANT',
        accessPolicy: 'PUBLIC',
      },
      {
        id: U.space.planner,
        slug: 'planner',
        name: '기획자 커뮤니티',
        audience: 'PLANNER',
        accessPolicy: 'PLANNER_ONLY', // milestone 4: now enforced
      },
    ],
  });
  await prisma.category.createMany({
    data: [
      {
        id: U.category.loveContent,
        spaceId: U.space.participant,
        slug: 'love-content',
        name: '연애 콘텐츠',
        description: '연애 예능과 오프라인 매칭 이벤트 포맷을 모아보는 허브',
        sortOrder: 1,
      },
      // Milestone 4: planner-side staff/operations hub.
      {
        id: U.category.plannerStaff,
        spaceId: U.space.planner,
        slug: 'planner-staff',
        name: '스태프 / 스튜디오',
        description: '스태프 모집, 운영 노트, 콘텐츠 기획 토론이 이뤄지는 기획자 전용 공간',
        sortOrder: 1,
      },
    ],
  });
}

async function seedTopicHub(prisma: PrismaClient): Promise<void> {
  await prisma.topicHub.create({
    data: {
      id: U.topicHub.loveContent,
      categoryId: U.category.loveContent,
      title: '연애 예능과 오프라인 매칭',
      summary:
        '연애 예능 포맷과 오프라인 매칭 이벤트의 인기 룰, 추천 인원, 분위기 팁, 자주 묻는 질문을 정리합니다.',
    },
  });

  await prisma.knowledgeBlock.createMany({
    data: [
      {
        id: U.block.overview,
        topicHubId: U.topicHub.loveContent,
        blockType: 'OVERVIEW',
        title: '개요',
        body: '연애 콘텐츠는 예능 포맷에서 출발한 오프라인 매칭/소셜링 경험을 다룹니다. Club에서는 포맷, 룰, 분위기, 후기를 함께 정리합니다.',
        sortOrder: 1,
      },
      {
        id: U.block.popularFormat,
        topicHubId: U.topicHub.loveContent,
        blockType: 'POPULAR_FORMAT',
        title: '인기 포맷',
        body: '선택 룸, 팀 미션, 1:1 토크 라운드가 자주 등장합니다. 룰이 단순하고 어색함이 빨리 풀리는 포맷이 인기가 많습니다.',
        sortOrder: 2,
      },
      {
        id: U.block.partySize,
        topicHubId: U.topicHub.loveContent,
        blockType: 'RECOMMENDED_PARTY_SIZE',
        title: '추천 인원',
        body: '12-24명 규모가 가장 자주 운영됩니다. 8-10명 소규모는 깊은 대화에, 24명 이상은 팀 게임에 적합합니다.',
        sortOrder: 3,
      },
      {
        id: U.block.moodTips,
        topicHubId: U.topicHub.loveContent,
        blockType: 'MOOD_TIPS',
        title: '분위기 팁',
        body: '도입부 5분에 어색함 완화 미션을 두면 만족도가 올라갑니다. 토크 중심 라운드는 음악 볼륨을 낮춰 두는 것이 좋습니다.',
        sortOrder: 4,
      },
      {
        id: U.block.faq,
        topicHubId: U.topicHub.loveContent,
        blockType: 'FAQ',
        title: 'FAQ',
        // Post-approval body (see seedKnowledgeContributions:approvedFaqEdit
        // for the snapshot of the pre-approval text — kept on the contribution
        // row as the M2 audit trail).
        body:
          'Q. 처음 가도 어색하지 않을까요?\n' +
          'A. 대부분 첫 만남이라 운영자가 도입부 미션을 준비합니다.\n\n' +
          'Q. 따로 준비물이 필요한가요?\n' +
          'A. 별도 준비물은 없고, 편한 복장과 가벼운 마음만 챙겨오시면 됩니다.',
        sortOrder: 5,
      },
      {
        id: U.block.warning,
        topicHubId: U.topicHub.loveContent,
        blockType: 'WARNING',
        title: '주의사항',
        body: '참가자 사생활을 콘텐츠에 노출하지 않습니다. 사전 동의 없는 사진/영상 공유는 금지됩니다.',
        sortOrder: 6,
      },
    ],
  });

  await prisma.topicSignal.createMany({
    data: [
      {
        id: U.signal.popularRef,
        topicHubId: U.topicHub.loveContent,
        signalType: 'POPULAR_REFERENCE_COUNT',
        title: '많이 저장된 레퍼런스',
        payload: { count: 2 },
      },
      {
        id: U.signal.hotDebate,
        topicHubId: U.topicHub.loveContent,
        signalType: 'HOT_DEBATE_TITLE',
        title: '댓글 많은 쟁점',
        payload: { text: '첫 만남 미션은 어디까지 괜찮나' },
      },
      {
        id: U.signal.verifiedReviews,
        topicHubId: U.topicHub.loveContent,
        signalType: 'VERIFIED_REVIEW_COUNT',
        title: '참가 인증 후기 수',
        payload: { count: 12 },
      },
    ],
  });
}

async function seedEventsAndReferences(prisma: PrismaClient): Promise<void> {
  await prisma.eventCard.createMany({
    data: [
      {
        id: U.event.e001,
        externalEventId: 'evt-001',
        title: 'PRISM 소개팅 미션 나이트',
        venueName: '홍대 스튜디오',
        region: '서울/홍대',
        startsAt: DAYS(-21),
        eventStatus: 'COMPLETED',
        thumbnailUrl: null,
      },
      {
        id: U.event.e002,
        externalEventId: 'evt-002',
        title: '환승연애 토크 라운드',
        venueName: '성수 라운지',
        region: '서울/성수',
        startsAt: DAYS(30),
        eventStatus: 'UPCOMING',
        thumbnailUrl: null,
      },
      {
        id: U.event.e003,
        externalEventId: 'evt-003',
        title: '첫 만남 게임 워크숍',
        venueName: '강남 미팅룸',
        region: '서울/강남',
        startsAt: DAYS(14),
        eventStatus: 'UPCOMING',
        thumbnailUrl: null,
      },
    ],
  });

  await prisma.reference.createMany({
    data: [
      {
        id: U.reference.swapTalkAnalysis,
        createdBy: U.user.minseo,
        type: 'TV_SHOW',
        url: 'https://example.com/heart-signal-analysis',
        title: '환승연애 대화 구조 분석',
        sourceName: '블로그 정리',
      },
      {
        id: U.reference.selectRuleYoutube,
        createdBy: U.user.haneul,
        type: 'YOUTUBE',
        url: 'https://www.youtube.com/watch?v=demo01',
        title: '연애 예능 속 선택 룰 모음',
        sourceName: 'YouTube',
      },
      {
        id: U.reference.firstMeetingIdeas,
        createdBy: U.user.haneul,
        type: 'IDEA',
        url: 'https://example.com/first-meeting-ideas',
        title: '첫 만남 미션 아이디어 노트',
        sourceName: 'PRISM Studio',
      },
    ],
  });

  // Hub-level recommendation links.
  await prisma.topicHubEventLink.createMany({
    data: [
      { topicHubId: U.topicHub.loveContent, eventCardId: U.event.e001, sortOrder: 1 },
      { topicHubId: U.topicHub.loveContent, eventCardId: U.event.e002, sortOrder: 2 },
      { topicHubId: U.topicHub.loveContent, eventCardId: U.event.e003, sortOrder: 3 },
    ],
  });
  await prisma.topicHubReferenceLink.createMany({
    data: [
      { topicHubId: U.topicHub.loveContent, referenceId: U.reference.swapTalkAnalysis, sortOrder: 1 },
      { topicHubId: U.topicHub.loveContent, referenceId: U.reference.selectRuleYoutube, sortOrder: 2 },
      { topicHubId: U.topicHub.loveContent, referenceId: U.reference.firstMeetingIdeas, sortOrder: 3 },
    ],
  });
}

async function seedRooms(prisma: PrismaClient): Promise<void> {
  await prisma.room.createMany({
    data: [
      {
        id: U.room.datingReviews,
        categoryId: U.category.loveContent,
        ownerId: null,
        slug: 'dating-event-reviews',
        name: '소개팅/매칭 이벤트 후기',
        description: '소개팅과 매칭 이벤트 참가 후기를 모아 봅니다.',
        origin: 'OFFICIAL',
        roomType: 'EVENT_REACTION',
        tags: ['소개팅', '매칭'],
      },
      {
        id: U.room.loveShowRefs,
        categoryId: U.category.loveContent,
        ownerId: null,
        slug: 'love-show-references',
        name: '연애 예능 레퍼런스',
        description: '연애 예능 포맷과 룰 레퍼런스를 모읍니다.',
        origin: 'OFFICIAL',
        roomType: 'REFERENCE',
        tags: ['예능', '레퍼런스'],
      },
      {
        id: U.room.swapTalkGame,
        categoryId: U.category.loveContent,
        ownerId: U.user.haneul,
        slug: 'swap-style-talk-game',
        name: '환승연애식 오프라인 토크 게임',
        description: '예능 포맷을 오프라인 이벤트로 바꾸는 아이디어를 나눠요.',
        origin: 'USER',
        roomType: 'DISCUSSION',
        tags: ['환승연애', '토크게임'],
      },
    ],
  });

  await prisma.roomPin.createMany({
    data: [
      // dating-event-reviews pins evt-001
      {
        roomId: U.room.datingReviews,
        targetType: 'EVENT_CARD',
        targetId: U.event.e001,
        sortOrder: 1,
      },
      // love-show-references pins the swap-talk analysis reference
      {
        roomId: U.room.loveShowRefs,
        targetType: 'REFERENCE',
        targetId: U.reference.swapTalkAnalysis,
        sortOrder: 1,
      },
      // swap-talk-game pins evt-002 + select-rule youtube
      {
        roomId: U.room.swapTalkGame,
        targetType: 'EVENT_CARD',
        targetId: U.event.e002,
        sortOrder: 1,
      },
      {
        roomId: U.room.swapTalkGame,
        targetType: 'REFERENCE',
        targetId: U.reference.selectRuleYoutube,
        sortOrder: 2,
      },
    ],
  });
}

async function seedPostsAndReplies(prisma: PrismaClient): Promise<void> {
  // Post 1: minseo review with event-card evt-001
  await prisma.post.create({
    data: {
      id: U.post.minseoReview,
      roomId: U.room.datingReviews,
      authorId: U.user.minseo,
      body: 'PRISM 소개팅 미션 나이트, 처음엔 어색했는데 팀 미션이 시작되고 분위기가 풀렸어요. 다음 라운드도 기대됩니다.',
      attachments: {
        create: [
          { attachmentType: 'EVENT_CARD', targetId: U.event.e001, sortOrder: 1 },
        ],
      },
    },
  });

  // Post 2: joon question, no attachment
  await prisma.post.create({
    data: {
      id: U.post.joonQuestion,
      roomId: U.room.datingReviews,
      authorId: U.user.joon,
      body: '팀 미션에서 시간이 너무 짧지 않았나요? 라운드 1개 더 있었으면 좋았을 듯해요.',
    },
  });

  // Post 3: haneul idea with reference
  await prisma.post.create({
    data: {
      id: U.post.haneulIdea,
      roomId: U.room.swapTalkGame,
      authorId: U.user.haneul,
      body: '환승연애 룸 선택 룰을 오프라인 토크 게임으로 옮기면 이런 식으로 바꿔볼 수 있을 것 같아요.',
      attachments: {
        create: [
          { attachmentType: 'REFERENCE', targetId: U.reference.selectRuleYoutube, sortOrder: 1 },
        ],
      },
    },
  });

  // Replies on Post 1 (minseo's review): joon → minseo (depth 2), haneul flat
  const r1Joon = await prisma.reply.create({
    data: {
      postId: U.post.minseoReview,
      authorId: U.user.joon,
      body: '그 미션 몇 분 정도 걸렸나요?',
    },
  });
  await prisma.reply.create({
    data: {
      postId: U.post.minseoReview,
      parentReplyId: r1Joon.id,
      authorId: U.user.minseo,
      body: '10분 정도가 딱 좋았어요.',
    },
  });
  await prisma.reply.create({
    data: {
      postId: U.post.minseoReview,
      authorId: U.user.haneul,
      body: '다음엔 선택지 공개 타이밍을 늦추면 더 재밌을 듯해요.',
    },
  });

  // Replies on Post 2 (joon's question): minseo flat
  await prisma.reply.create({
    data: {
      postId: U.post.joonQuestion,
      authorId: U.user.minseo,
      body: '확실히 라운드 1개 더 있으면 좋았겠어요.',
    },
  });

  // Replies on Post 3 (haneul's idea): minseo → haneul (depth 2)
  const r3Minseo = await prisma.reply.create({
    data: {
      postId: U.post.haneulIdea,
      authorId: U.user.minseo,
      body: '토크 게임용 카드 디자인은 어떻게 하실 거예요?',
    },
  });
  await prisma.reply.create({
    data: {
      postId: U.post.haneulIdea,
      parentReplyId: r3Minseo.id,
      authorId: U.user.haneul,
      body: '프린트 카드 30장 정도로 시작해 보려고요.',
    },
  });

  // Refresh reply_count on each post based on actual replies.
  for (const postId of [U.post.minseoReview, U.post.joonQuestion, U.post.haneulIdea]) {
    const count = await prisma.reply.count({ where: { postId } });
    await prisma.post.update({ where: { id: postId }, data: { replyCount: count } });
  }
}

async function seedKnowledgeContributions(prisma: PrismaClient): Promise<void> {
  // Pending: refine MOOD_TIPS with extra context, attaching a reference as evidence.
  await prisma.knowledgeContribution.create({
    data: {
      id: U.contribution.pendingMoodTipsEdit,
      topicHubId: U.topicHub.loveContent,
      contributorId: U.user.minseo,
      targetBlockId: U.block.moodTips,
      proposedBlockType: 'MOOD_TIPS',
      proposedTitle: '분위기 팁',
      proposedBody:
        '도입부 5분에 어색함 완화 미션을 두면 만족도가 올라갑니다. ' +
        '토크 중심 라운드는 음악 볼륨을 낮추고, 진행자가 직접 한두 마디를 던지면 ' +
        '참가자가 따라오기가 쉬워집니다.',
      evidenceType: 'REFERENCE',
      evidenceTargetId: U.reference.selectRuleYoutube,
      status: 'PENDING',
    },
  });

  // Pending: propose a brand-new CHECKLIST block, with an EventCard as evidence.
  await prisma.knowledgeContribution.create({
    data: {
      id: U.contribution.pendingNewChecklist,
      topicHubId: U.topicHub.loveContent,
      contributorId: U.user.haneul,
      targetBlockId: null,
      proposedBlockType: 'CHECKLIST',
      proposedTitle: '운영 체크리스트',
      proposedBody:
        '1. 도입부 5분 어색함 완화 미션 준비\n' +
        '2. 라운드별 시간표 인쇄\n' +
        '3. 비상 대응 인력 1명 이상 확보\n' +
        '4. 행사 후 후기 작성 안내',
      evidenceType: 'EVENT_CARD',
      evidenceTargetId: U.event.e002,
      status: 'PENDING',
    },
  });

  // Approved (already applied): demonstrates the audit-snapshot capture.
  // The FAQ block above carries the post-approval body; the snapshot here is
  // the pre-approval (milestone-1) text that was overwritten.
  await prisma.knowledgeContribution.create({
    data: {
      id: U.contribution.approvedFaqEdit,
      topicHubId: U.topicHub.loveContent,
      contributorId: U.user.joon,
      targetBlockId: U.block.faq,
      proposedBlockType: 'FAQ',
      proposedTitle: 'FAQ',
      proposedBody:
        'Q. 처음 가도 어색하지 않을까요?\n' +
        'A. 대부분 첫 만남이라 운영자가 도입부 미션을 준비합니다.\n\n' +
        'Q. 따로 준비물이 필요한가요?\n' +
        'A. 별도 준비물은 없고, 편한 복장과 가벼운 마음만 챙겨오시면 됩니다.',
      status: 'APPROVED',
      curatorNote: '추가 질문 항목이 명확해서 그대로 반영했습니다.',
      resolvedBy: U.user.coral,
      resolvedAt: new Date('2026-05-15T03:00:00Z'),
      snapshotBlockType: 'FAQ',
      snapshotTitle: 'FAQ',
      snapshotBody:
        'Q. 처음 가도 어색하지 않을까요?\nA. 대부분 첫 만남이라 운영자가 도입부 미션을 준비합니다.',
    },
  });
}

// -- Milestone 4: planner topic hub + recruitment ---------------------------

async function seedPlannerHub(prisma: PrismaClient): Promise<void> {
  await prisma.topicHub.create({
    data: {
      id: U.topicHub.plannerStaff,
      categoryId: U.category.plannerStaff,
      title: '스튜디오 스태프 협업 허브',
      summary:
        '인증된 기획자와 스태프가 모집·운영·회고를 함께 정리하는 공간입니다.',
    },
  });

  await prisma.knowledgeBlock.createMany({
    data: [
      {
        id: U.block.plannerOverview,
        topicHubId: U.topicHub.plannerStaff,
        blockType: 'OVERVIEW',
        title: '커뮤니티 사용 안내',
        body:
          '기획자 커뮤니티는 PRISM과 협업하는 검증된 기획자/스태프를 위한 공간입니다. ' +
          '스태프 모집 글은 모집 공지 → 상태 토글(모집 중/마감/충원 완료) 흐름으로 운영됩니다. ' +
          '비공식 외주, 정치/특정 종교 활동 등은 금지합니다.',
        sortOrder: 1,
      },
      {
        id: U.block.plannerFaq,
        topicHubId: U.topicHub.plannerStaff,
        blockType: 'FAQ',
        title: '자주 묻는 질문',
        body:
          'Q. 스태프 보상은 어떻게 지급되나요?\n' +
          'A. 각 모집 글의 보상 필드를 참고하시고, 세부 지급은 운영자와 협의합니다.\n\n' +
          'Q. 일정이 변경되면 어떻게 안내하나요?\n' +
          'A. 본문에 변경 사항을 추가하고 상태를 마감 또는 충원 완료로 토글해 주세요.',
        sortOrder: 2,
      },
      {
        id: U.block.plannerChecklist,
        topicHubId: U.topicHub.plannerStaff,
        blockType: 'CHECKLIST',
        title: '행사 준비 체크리스트',
        body:
          '1. 일정/장소 확정 후 모집 공지 작성\n' +
          '2. 역할·인원·보상·지원 방법 명시\n' +
          '3. 충원 완료 시 상태 토글\n' +
          '4. 행사 종료 후 회고 노트 작성',
        sortOrder: 3,
      },
    ],
  });
}

async function seedPlannerRooms(prisma: PrismaClient): Promise<void> {
  await prisma.room.create({
    data: {
      id: U.room.plannerRecruitment,
      categoryId: U.category.plannerStaff,
      ownerId: null,
      slug: 'planner-recruitment',
      name: '스태프 모집 공고',
      description: '행사 진행/음향/사진 어시 등 스태프 모집 공고가 모이는 방입니다.',
      origin: 'OFFICIAL',
      roomType: 'RECRUITMENT',
      tags: ['스태프', '모집'],
    },
  });
}

async function seedPlannerPosts(prisma: PrismaClient): Promise<void> {
  await prisma.post.create({
    data: {
      id: U.post.recruitDatingNight,
      roomId: U.room.plannerRecruitment,
      authorId: U.user.studio_lead,
      postType: 'RECRUITMENT',
      body:
        'PRISM 소개팅 미션 나이트 진행 스태프(어시) 모집합니다. 도입부 어색함 완화 미션 운영과 ' +
        '라운드 진행 보조를 맡아 주실 분을 찾고 있어요. 운영 경험 있으신 분 우대.',
      recruitmentFields: {
        role: '진행 어시스턴트',
        schedule: '5/30 19:00–22:00',
        location: '홍대 스튜디오',
        compensation: '8만원 + 식대',
        capacity: 2,
        application_method: 'DM @studio_lead',
        status: 'OPEN',
      },
    },
  });

  await prisma.post.create({
    data: {
      id: U.post.recruitTalkRound,
      roomId: U.room.plannerRecruitment,
      authorId: U.user.studio_mate,
      postType: 'RECRUITMENT',
      body:
        '환승연애 토크 라운드 음향 스태프(보조) 모집. 마이크 세팅, BGM 페이드, ' +
        '간단한 라이브 믹싱 가능하신 분 우대합니다.',
      recruitmentFields: {
        role: '음향 어시',
        schedule: '6/05 18:00–21:00',
        location: '성수 라운지',
        compensation: '10만원',
        capacity: 1,
        application_method: '이메일 hello@studio.example',
        status: 'OPEN',
      },
    },
  });

  await prisma.post.create({
    data: {
      id: U.post.recruitClosed,
      roomId: U.room.plannerRecruitment,
      authorId: U.user.studio_lead,
      postType: 'RECRUITMENT',
      body: '첫 만남 게임 워크숍 사진 스태프(어시) 모집 (마감). 현장 스냅과 그룹샷 위주.',
      recruitmentFields: {
        role: '사진 어시',
        schedule: '4/28 14:00–17:00',
        location: '강남 미팅룸',
        compensation: '5만원',
        capacity: 1,
        application_method: 'DM @studio_lead',
        status: 'CLOSED',
      },
    },
  });
}

export async function runSeed(prisma: PrismaClient): Promise<Record<string, number>> {
  await clearAll(prisma);
  await seedUsers(prisma);
  await seedSpacesAndCategories(prisma);
  await seedTopicHub(prisma);
  await seedEventsAndReferences(prisma);
  await seedRooms(prisma);
  await seedPostsAndReplies(prisma);
  await seedKnowledgeContributions(prisma);
  await seedPlannerHub(prisma);
  await seedPlannerRooms(prisma);
  await seedPlannerPosts(prisma);

  return {
    users: await prisma.user.count(),
    spaces: await prisma.space.count(),
    categories: await prisma.category.count(),
    topicHubs: await prisma.topicHub.count(),
    knowledgeBlocks: await prisma.knowledgeBlock.count(),
    topicSignals: await prisma.topicSignal.count(),
    eventCards: await prisma.eventCard.count(),
    references: await prisma.reference.count(),
    rooms: await prisma.room.count(),
    roomPins: await prisma.roomPin.count(),
    posts: await prisma.post.count(),
    replies: await prisma.reply.count(),
    postAttachments: await prisma.postAttachment.count(),
    userRoles: await prisma.userRole.count(),
    knowledgeContributions: await prisma.knowledgeContribution.count(),
    recruitmentPosts: await prisma.post.count({ where: { postType: 'RECRUITMENT' } }),
  };
}

// Allow `npm run db:seed` to invoke this file directly.
if (require.main === module) {
  const prisma = new PrismaClient();
  runSeed(prisma)
    .then((counts) => {
      // eslint-disable-next-line no-console
      console.log('Seed complete:', counts);
    })
    .catch((e) => {
      // eslint-disable-next-line no-console
      console.error(e);
      process.exit(1);
    })
    .finally(() => {
      void prisma.$disconnect();
    });
}
