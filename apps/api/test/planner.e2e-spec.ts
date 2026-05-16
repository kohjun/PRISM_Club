import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 4 — planner community + recruitment (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  const recruitmentBody = () => ({
    body:
      '음향 어시 한 분 모십니다. 마이크 세팅과 BGM 페이드, 라이브 믹싱 가능하신 분 우대.',
    post_type: 'RECRUITMENT',
    recruitment_fields: {
      role: '음향 어시',
      schedule: '6/12 18:00–21:00',
      location: '성수 라운지',
      compensation: '10만원',
      capacity: 1,
      application_method: 'DM @studio_lead',
    },
  });

  test('walks planner access + recruitment flow + search filtering', async () => {
    const server = ctx.app.getHttpServer();

    // 1. Member is blocked from listing planner categories.
    const memberCats = await request(server)
      .get('/v1/categories?spaceSlug=planner')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(memberCats.status).toBe(403);

    // 2. studio_lead (VERIFIED_PLANNER) sees the planner-staff category.
    const plannerCats = await request(server)
      .get('/v1/categories?spaceSlug=planner')
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(plannerCats.status).toBe(200);
    const slugs = plannerCats.body.items.map((c: any) => c.slug);
    expect(slugs).toContain('planner-staff');

    // 3. Member is blocked from reading the planner-recruitment room.
    const memberRoom = await request(server)
      .get('/v1/rooms/planner-recruitment')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(memberRoom.status).toBe(403);

    // 4. studio_lead can read the room and its timeline.
    const plannerRoom = await request(server)
      .get('/v1/rooms/planner-recruitment')
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(plannerRoom.status).toBe(200);
    expect(plannerRoom.body.slug).toBe('planner-recruitment');
    expect(plannerRoom.body.room_type).toBe('RECRUITMENT');

    const timeline = await request(server)
      .get('/v1/rooms/planner-recruitment/timeline')
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(timeline.status).toBe(200);
    expect(timeline.body.items.length).toBeGreaterThanOrEqual(3); // seeded posts

    // 5. studio_lead creates a new RECRUITMENT post with valid fields.
    const create = await request(server)
      .post('/v1/rooms/planner-recruitment/posts')
      .set(HEAD(ctx.uuids.user.studio_lead))
      .send(recruitmentBody());
    expect(create.status).toBe(201);
    expect(create.body.post_type).toBe('RECRUITMENT');
    expect(create.body.recruitment_fields).not.toBeNull();
    expect(create.body.recruitment_fields.status).toBe('OPEN');
    expect(create.body.recruitment_fields.role).toBe('음향 어시');
    const newPostId = create.body.id;

    // 6. Member is blocked from creating in the planner room.
    const memberCreate = await request(server)
      .post('/v1/rooms/planner-recruitment/posts')
      .set(HEAD(ctx.uuids.user.minseo))
      .send(recruitmentBody());
    expect(memberCreate.status).toBe(403);

    // 7. Author flips status OPEN → CLOSED.
    const close = await request(server)
      .post(`/v1/posts/${newPostId}/recruitment-status`)
      .set(HEAD(ctx.uuids.user.studio_lead))
      .send({ status: 'CLOSED' });
    expect(close.status).toBe(201);
    expect(close.body.recruitment_fields.status).toBe('CLOSED');

    // 8. studio_mate (a different VERIFIED_PLANNER) cannot toggle status.
    const otherToggle = await request(server)
      .post(`/v1/posts/${newPostId}/recruitment-status`)
      .set(HEAD(ctx.uuids.user.studio_mate))
      .send({ status: 'OPEN' });
    expect(otherToggle.status).toBe(403);

    // 9. RECRUITMENT post requires recruitment_fields.
    const missingFields = await request(server)
      .post('/v1/rooms/planner-recruitment/posts')
      .set(HEAD(ctx.uuids.user.studio_lead))
      .send({ body: 'no fields', post_type: 'RECRUITMENT' });
    expect(missingFields.status).toBe(400);

    // 10. RECRUITMENT post forbidden in non-RECRUITMENT room (blocked at access for member; here we use studio_lead in love-content room).
    // dating-event-reviews is in the participant space, so studio_lead has access (PUBLIC) — should hit the 400 invariant.
    const wrongRoom = await request(server)
      .post('/v1/rooms/dating-event-reviews/posts')
      .set(HEAD(ctx.uuids.user.studio_lead))
      .send(recruitmentBody());
    expect(wrongRoom.status).toBe(400);

    // 11. Search filtering — member finds no recruitment posts on planner-space query.
    const memberSearch = await request(server)
      .get(`/v1/search?q=${encodeURIComponent('스태프')}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(memberSearch.status).toBe(200);
    const memberPosts = memberSearch.body.groups.find((g: any) => g.type === 'post').items;
    expect(memberPosts.length).toBe(0);

    // 12. Verified planner search returns recruitment posts.
    const plannerSearch = await request(server)
      .get(`/v1/search?q=${encodeURIComponent('스태프')}`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(plannerSearch.status).toBe(200);
    const plannerPosts = plannerSearch.body.groups.find((g: any) => g.type === 'post').items;
    expect(plannerPosts.length).toBeGreaterThanOrEqual(1);

    // 13. Suggestions for planner-staff are tuned.
    const sugg = await request(server)
      .get('/v1/search/suggestions?categorySlug=planner-staff')
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(sugg.status).toBe(200);
    expect(sugg.body.items).toContain('스태프');
  });
});
