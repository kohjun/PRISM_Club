import { NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { ProfileShareService } from './profile-share.service';

describe('ProfileShareService', () => {
  let ctx: TestContext;
  let svc: ProfileShareService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(ProfileShareService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('getShareCard returns title + badges + deep link for active user', async () => {
    const card = await svc.getShareCard(ctx.uuids.user.minseo);
    expect(card.user_id).toBe(ctx.uuids.user.minseo);
    expect(card.title).toBe('민서');
    expect(card.deep_link).toContain('/share/profile/');
    expect(card.og_image_url).toContain('/v1/og/profile/');
    expect(card.badges.length).toBeGreaterThanOrEqual(1);
    expect(card.badges[0].kind).toBe('TIER');
  });

  test('getShareCard throws NotFound for unknown user', async () => {
    await expect(
      svc.getShareCard('00000000-0000-0000-0000-000000000000'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  test('getOgPng returns a PNG buffer and caches subsequent calls', async () => {
    const first = await svc.getOgPng(ctx.uuids.user.minseo);
    expect(first.length).toBeGreaterThan(100);
    // PNG magic header.
    expect(first.subarray(0, 4).toString('hex')).toBe('89504e47');
    const second = await svc.getOgPng(ctx.uuids.user.minseo);
    expect(second).toBe(first);
  });
});
