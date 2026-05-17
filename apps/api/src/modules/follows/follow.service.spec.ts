import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { FollowService } from './follow.service';

describe('FollowService', () => {
  let ctx: TestContext;
  let svc: FollowService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(FollowService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('toggle follow creates a row and returns followed=true', async () => {
    // joon is not seeded as a follower of dating-event-reviews
    const state = await svc.toggle('dating-event-reviews', asUser(ctx.uuids.user.joon));
    expect(state.followed).toBe(true);
    expect(state.follower_count).toBeGreaterThanOrEqual(1);
  });

  test('toggle again (unfollow) removes the row and returns followed=false', async () => {
    // haneul has no existing follow — follow then unfollow
    await svc.toggle('swap-style-talk-game', asUser(ctx.uuids.user.haneul));
    const state = await svc.toggle('swap-style-talk-game', asUser(ctx.uuids.user.haneul));
    expect(state.followed).toBe(false);
  });

  test('getState reflects seed follows for minseo', async () => {
    const state = await svc.getState('dating-event-reviews', ctx.uuids.user.minseo);
    expect(state.followed).toBe(true);
    expect(state.follower_count).toBeGreaterThanOrEqual(1);
  });
});
