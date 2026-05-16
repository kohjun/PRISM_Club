import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { PostService } from './post.service';

describe('PostService', () => {
  let ctx: TestContext;
  let posts: PostService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    posts = ctx.app.get(PostService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('create writes both attachment types in one transaction', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      {
        body: 'attachment test',
        attachments: [
          { attachment_type: 'EVENT_CARD', target_id: ctx.uuids.event.e001 },
          { attachment_type: 'REFERENCE', target_id: ctx.uuids.reference.selectRuleYoutube },
        ],
      },
      asUser(ctx.uuids.user.minseo),
    );
    expect(post.attachments).toHaveLength(2);
    const types = post.attachments.map((a) => a.attachment_type).sort();
    expect(types).toEqual(['EVENT_CARD', 'REFERENCE']);
  });

  test('rejects unknown attachment target', async () => {
    await expect(
      posts.create(
        'dating-event-reviews',
        {
          body: 'bad attachment',
          attachments: [
            {
              attachment_type: 'EVENT_CARD',
              target_id: '00000000-0000-0000-0000-000000000000',
            },
          ],
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  test('update is author-only', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'mine' },
      asUser(ctx.uuids.user.minseo),
    );
    await expect(
      posts.update(post.id, 'hostile edit', asUser(ctx.uuids.user.joon)),
    ).rejects.toBeInstanceOf(ForbiddenException);
    const ok = await posts.update(post.id, 'self edit', asUser(ctx.uuids.user.minseo));
    expect(ok.body).toBe('self edit');
  });

  test('softDelete hides post from getById', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'transient' },
      asUser(ctx.uuids.user.minseo),
    );
    await posts.softDelete(post.id, asUser(ctx.uuids.user.minseo));
    await expect(
      posts.getById(post.id, asUser(ctx.uuids.user.minseo)),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  // -- Milestone 4: recruitment posts ----------------------------------

  const validRecruitmentFields = () => ({
    role: '진행 어시스턴트',
    schedule: '5/30 19:00–22:00',
    location: '홍대 스튜디오',
    compensation: '8만원 + 식대',
    capacity: 2,
    application_method: 'DM @studio_lead',
  });

  test('rejects RECRUITMENT post in non-RECRUITMENT room (room invariant)', async () => {
    // studio_lead has access to participant-space PUBLIC rooms, so the access
    // gate passes — we hit the room.roomType invariant which throws 400.
    await expect(
      posts.create(
        'dating-event-reviews',
        {
          body: 'recruit body',
          post_type: 'RECRUITMENT',
          recruitment_fields: validRecruitmentFields(),
        },
        asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('rejects RECRUITMENT post without recruitment_fields', async () => {
    await expect(
      posts.create(
        'planner-recruitment',
        {
          body: 'no fields',
          post_type: 'RECRUITMENT',
        },
        asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('creates RECRUITMENT post with status defaulted to OPEN', async () => {
    const post = await posts.create(
      'planner-recruitment',
      {
        body: '진행 어시 한 분 모셔요',
        post_type: 'RECRUITMENT',
        recruitment_fields: validRecruitmentFields(),
      },
      asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
    );
    expect(post.post_type).toBe('RECRUITMENT');
    expect(post.recruitment_fields).not.toBeNull();
    expect(post.recruitment_fields!.status).toBe('OPEN');
    expect(post.recruitment_fields!.role).toBe('진행 어시스턴트');
  });

  test('setRecruitmentStatus by author flips OPEN → CLOSED', async () => {
    const post = await posts.create(
      'planner-recruitment',
      {
        body: 'toggle target',
        post_type: 'RECRUITMENT',
        recruitment_fields: validRecruitmentFields(),
      },
      asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
    );
    const closed = await posts.setRecruitmentStatus(
      post.id,
      'CLOSED',
      asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
    );
    expect(closed.recruitment_fields!.status).toBe('CLOSED');
  });

  test('setRecruitmentStatus rejects non-author non-admin', async () => {
    const post = await posts.create(
      'planner-recruitment',
      {
        body: 'other-author target',
        post_type: 'RECRUITMENT',
        recruitment_fields: validRecruitmentFields(),
      },
      asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
    );
    await expect(
      posts.setRecruitmentStatus(
        post.id,
        'FILLED',
        asUser(ctx.uuids.user.studio_mate, ['VERIFIED_PLANNER']),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  test('setRecruitmentStatus rejects GENERAL post', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'general post' },
      asUser(ctx.uuids.user.minseo),
    );
    await expect(
      posts.setRecruitmentStatus(post.id, 'CLOSED', asUser(ctx.uuids.user.minseo)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('MEMBER trying to create in planner room → 403', async () => {
    await expect(
      posts.create(
        'planner-recruitment',
        {
          body: 'sneak attempt',
          post_type: 'RECRUITMENT',
          recruitment_fields: validRecruitmentFields(),
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
