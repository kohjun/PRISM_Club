import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 5 — event detail (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('walks fetch → compose-pre-attach → re-fetch → access-policy isolation', async () => {
    const server = ctx.app.getHttpServer();
    const e001 = ctx.uuids.event.e001;

    // 1. Unknown event id → 404.
    const missing = await request(server)
      .get('/v1/event-cards/00000000-0000-0000-0000-000000000000')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(missing.status).toBe(404);

    // 2. As minseo, fetch evt-001 detail → 200 with related_posts/rooms.
    const detail = await request(server)
      .get(`/v1/event-cards/${e001}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(detail.status).toBe(200);
    expect(detail.body.event_card.external_event_id).toBe('evt-001');
    expect(detail.body.related_posts.items.length).toBeGreaterThanOrEqual(1);
    expect(detail.body.related_rooms.length).toBeGreaterThanOrEqual(1);
    expect(detail.body.default_compose_room_slug).toBe('dating-event-reviews');
    const initialPostCount = detail.body.counts.post_count;

    // 3. As minseo, create a new post attaching evt-001 — simulates the
    //    composer pre-attach round trip.
    const create = await request(server)
      .post('/v1/rooms/dating-event-reviews/posts')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({
        body: 'e2e: pre-attached evt-001 post',
        attachments: [
          { attachment_type: 'EVENT_CARD', target_id: e001 },
        ],
      });
    expect(create.status).toBe(201);
    const newPostId = create.body.id;

    // 4. Re-fetch detail; post count rose by 1 and the new post appears.
    const after = await request(server)
      .get(`/v1/event-cards/${e001}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(after.status).toBe(200);
    expect(after.body.counts.post_count).toBe(initialPostCount + 1);
    expect(
      after.body.related_posts.items.some((p: any) => p.id === newPostId),
    ).toBe(true);

    // 5. Planner-space isolation: studio_lead creates a recruitment post
    //    in planner-recruitment also attaching evt-001.
    const plannerCreate = await request(server)
      .post('/v1/rooms/planner-recruitment/posts')
      .set(HEAD(ctx.uuids.user.studio_lead))
      .send({
        body: 'planner: recruiting staff for evt-001 day',
        post_type: 'RECRUITMENT',
        recruitment_fields: {
          role: '진행 어시',
          schedule: 'evt-001 18:00',
          location: '홍대 스튜디오',
          compensation: '8만원',
          capacity: 1,
          application_method: 'DM @studio_lead',
        },
        attachments: [
          { attachment_type: 'EVENT_CARD', target_id: e001 },
        ],
      });
    expect(plannerCreate.status).toBe(201);
    const plannerPostId = plannerCreate.body.id;

    // 6. Member fetch must NOT include the planner post.
    const memberFetch = await request(server)
      .get(`/v1/event-cards/${e001}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(memberFetch.status).toBe(200);
    expect(
      memberFetch.body.related_posts.items.some(
        (p: any) => p.id === plannerPostId,
      ),
    ).toBe(false);
    expect(
      memberFetch.body.related_rooms.some(
        (r: any) => r.slug === 'planner-recruitment',
      ),
    ).toBe(false);

    // 7. Planner fetch DOES include the planner post + room.
    const plannerFetch = await request(server)
      .get(`/v1/event-cards/${e001}`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(plannerFetch.status).toBe(200);
    expect(
      plannerFetch.body.related_posts.items.some(
        (p: any) => p.id === plannerPostId,
      ),
    ).toBe(true);
    expect(
      plannerFetch.body.related_rooms.some(
        (r: any) => r.slug === 'planner-recruitment',
      ),
    ).toBe(true);

    // 8. evt-003 path: empty related_posts but default_compose_room_slug
    //    still resolves via topic_hub_event_links.
    const e003Detail = await request(server)
      .get(`/v1/event-cards/${ctx.uuids.event.e003}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(e003Detail.status).toBe(200);
    expect(e003Detail.body.related_posts.items).toHaveLength(0);
    expect(e003Detail.body.default_compose_room_slug).toBe('dating-event-reviews');
  });
});
