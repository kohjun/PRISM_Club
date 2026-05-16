import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../test/test-app';
import { AccessControlService } from './access-control.service';

describe('AccessControlService', () => {
  let ctx: TestContext;
  let svc: AccessControlService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(AccessControlService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  const member = { roles: ['MEMBER'] };
  const planner = { roles: ['VERIFIED_PLANNER'] };
  const admin = { roles: ['ADMIN'] };
  const curator = { roles: ['CURATOR'] };

  // -- allowed-policy set ------------------------------------------------

  test('accessPoliciesAllowedFor MEMBER returns only PUBLIC', () => {
    expect(svc.accessPoliciesAllowedFor(member)).toEqual(['PUBLIC']);
  });

  test('accessPoliciesAllowedFor VERIFIED_PLANNER includes PLANNER_ONLY', () => {
    expect(svc.accessPoliciesAllowedFor(planner)).toEqual([
      'PUBLIC',
      'PLANNER_ONLY',
    ]);
  });

  test('accessPoliciesAllowedFor ADMIN includes PLANNER_ONLY', () => {
    expect(svc.accessPoliciesAllowedFor(admin)).toEqual([
      'PUBLIC',
      'PLANNER_ONLY',
    ]);
  });

  test('accessPoliciesAllowedFor CURATOR alone does NOT include PLANNER_ONLY', () => {
    expect(svc.accessPoliciesAllowedFor(curator)).toEqual(['PUBLIC']);
  });

  // -- isVerifiedPlanner -------------------------------------------------

  test('isVerifiedPlanner true for VERIFIED_PLANNER and ADMIN', () => {
    expect(svc.isVerifiedPlanner(planner)).toBe(true);
    expect(svc.isVerifiedPlanner(admin)).toBe(true);
  });

  test('isVerifiedPlanner false for MEMBER and CURATOR', () => {
    expect(svc.isVerifiedPlanner(member)).toBe(false);
    expect(svc.isVerifiedPlanner(curator)).toBe(false);
  });

  // -- assertCanReadSpaceBySlug -----------------------------------------

  test('participant space readable by any role', async () => {
    await expect(
      svc.assertCanReadSpaceBySlug('participant', member),
    ).resolves.toBeUndefined();
    await expect(
      svc.assertCanReadSpaceBySlug('participant', curator),
    ).resolves.toBeUndefined();
    await expect(
      svc.assertCanReadSpaceBySlug('participant', planner),
    ).resolves.toBeUndefined();
  });

  test('planner space blocked for MEMBER', async () => {
    await expect(
      svc.assertCanReadSpaceBySlug('planner', member),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  test('planner space readable by VERIFIED_PLANNER and ADMIN', async () => {
    await expect(
      svc.assertCanReadSpaceBySlug('planner', planner),
    ).resolves.toBeUndefined();
    await expect(
      svc.assertCanReadSpaceBySlug('planner', admin),
    ).resolves.toBeUndefined();
  });

  test('planner space blocked for CURATOR alone', async () => {
    await expect(
      svc.assertCanReadSpaceBySlug('planner', curator),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  test('unknown space slug throws NotFound', async () => {
    await expect(
      svc.assertCanReadSpaceBySlug('does-not-exist', member),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  // -- assertCanReadCategoryBySlug --------------------------------------

  test('love-content category readable by MEMBER', async () => {
    await expect(
      svc.assertCanReadCategoryBySlug('love-content', member),
    ).resolves.toBeUndefined();
  });

  test('planner-staff category blocked for MEMBER, allowed for planner', async () => {
    await expect(
      svc.assertCanReadCategoryBySlug('planner-staff', member),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      svc.assertCanReadCategoryBySlug('planner-staff', planner),
    ).resolves.toBeUndefined();
  });

  // -- assertCanReadRoomBySlug ------------------------------------------

  test('participant room readable by MEMBER', async () => {
    await expect(
      svc.assertCanReadRoomBySlug('dating-event-reviews', member),
    ).resolves.toBeUndefined();
  });

  test('planner-recruitment room blocked for MEMBER, allowed for planner', async () => {
    await expect(
      svc.assertCanReadRoomBySlug('planner-recruitment', member),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      svc.assertCanReadRoomBySlug('planner-recruitment', planner),
    ).resolves.toBeUndefined();
  });
});
