import { BadRequestException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { UserProfileService } from './user-profile.service';

describe('UserProfileService', () => {
  let ctx: TestContext;
  let svc: UserProfileService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(UserProfileService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('getProfileBundle for minseo as joon returns full structure', async () => {
    const bundle = await svc.getProfileBundle(
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.joon),
    );
    expect(bundle.user.id).toBe(ctx.uuids.user.minseo);
    expect(bundle.user.nickname).toBe('민서');
    expect(bundle.profile.bio).toContain('이벤트 후기');
    expect(bundle.profile.interests.length).toBeGreaterThanOrEqual(1);
    expect(bundle.roles).toEqual([]); // minseo has no extra role rows
    expect(bundle.counts.post_count).toBeGreaterThanOrEqual(1);
    expect(bundle.recent_posts.length).toBeGreaterThanOrEqual(1);
    expect(bundle.is_self).toBe(false);
    // joon follows minseo per seed
    expect(bundle.is_following).toBe(true);
  });

  test('Member viewing studio_lead profile excludes recruitment posts', async () => {
    const bundle = await svc.getProfileBundle(
      ctx.uuids.user.studio_lead,
      asUser(ctx.uuids.user.minseo, ['MEMBER']),
    );
    // No recruitment posts visible to a member; studio_lead has 3 recruitment
    // posts in PLANNER_ONLY space.
    expect(bundle.recent_posts.length).toBe(0);
    expect(bundle.counts.post_count).toBe(0);
  });

  test('Verified planner viewing studio_lead profile sees recruitment posts', async () => {
    const bundle = await svc.getProfileBundle(
      ctx.uuids.user.studio_lead,
      asUser(ctx.uuids.user.studio_mate, ['VERIFIED_PLANNER']),
    );
    expect(bundle.recent_posts.length).toBeGreaterThanOrEqual(1);
    expect(bundle.counts.post_count).toBeGreaterThanOrEqual(1);
    expect(bundle.roles).toContain('VERIFIED_PLANNER');
  });

  test('updateMyProfile saves and trims bio; rejects bio > 500 chars', async () => {
    const result = await svc.updateMyProfile(ctx.uuids.user.joon, {
      bio: '  새 자기소개 테스트  ',
    });
    expect(result.bio).toBe('새 자기소개 테스트');

    await expect(
      svc.updateMyProfile(ctx.uuids.user.joon, { bio: 'a'.repeat(501) }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('updateMyProfile dedupes + lowercases interests; rejects > 10 items', async () => {
    const result = await svc.updateMyProfile(ctx.uuids.user.haneul, {
      interests: ['Korean', '한국어', 'KOREAN', ' korean '],
    });
    // 'Korean' → 'korean', ' korean ' → 'korean' (dedup); 'KOREAN' → 'korean' (dedup); '한국어' kept
    expect(result.interests).toEqual(['korean', '한국어']);

    await expect(
      svc.updateMyProfile(ctx.uuids.user.haneul, {
        interests: Array.from({ length: 11 }, (_, i) => `tag${i}`),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('updateMyProfile rejects unsupported keys', async () => {
    await expect(
      svc.updateMyProfile(ctx.uuids.user.minseo, {
        nickname: 'NEW',
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
