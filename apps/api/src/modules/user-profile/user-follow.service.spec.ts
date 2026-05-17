import { BadRequestException, NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { UserFollowService } from './user-follow.service';

describe('UserFollowService', () => {
  let ctx: TestContext;
  let svc: UserFollowService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(UserFollowService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('toggle follow → followed=true, follower_count incremented', async () => {
    // Seed has: joon → minseo (1 follower for minseo)
    const before = await svc.getState(ctx.uuids.user.minseo, ctx.uuids.user.haneul);
    expect(before.followed).toBe(false);
    const initialCount = before.follower_count;

    const after = await svc.toggle(ctx.uuids.user.minseo, ctx.uuids.user.haneul);
    expect(after.followed).toBe(true);
    expect(after.follower_count).toBe(initialCount + 1);
  });

  test('toggle again → followed=false, follower_count decremented', async () => {
    // Continuing from previous test: haneul now follows minseo. Toggle again.
    const back = await svc.toggle(ctx.uuids.user.minseo, ctx.uuids.user.haneul);
    expect(back.followed).toBe(false);
  });

  test('self-follow rejected with BadRequestException', async () => {
    await expect(
      svc.toggle(ctx.uuids.user.minseo, ctx.uuids.user.minseo),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('follow nonexistent user → NotFoundException', async () => {
    await expect(
      svc.toggle('00000000-0000-0000-0000-000000000000', ctx.uuids.user.minseo),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  test('getState returns correct followed + count for seeded follow', async () => {
    // joon → minseo per seed
    const state = await svc.getState(ctx.uuids.user.minseo, ctx.uuids.user.joon);
    expect(state.followed).toBe(true);
    expect(state.follower_count).toBeGreaterThanOrEqual(1);
  });
});
