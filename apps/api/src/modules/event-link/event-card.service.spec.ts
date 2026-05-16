import { NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { EventCardService } from './event-card.service';

describe('EventCardService', () => {
  let ctx: TestContext;
  let events: EventCardService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    events = ctx.app.get(EventCardService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('search by query returns matching mock events', async () => {
    const results = await events.search('환승');
    expect(results.length).toBeGreaterThanOrEqual(2);
  });

  test('upsert is idempotent on external_event_id', async () => {
    const a = await events.upsertFromExternal('evt-102');
    const b = await events.upsertFromExternal('evt-102');
    expect(b.id).toBe(a.id);
  });

  test('upsert with unknown external id throws NotFound', async () => {
    await expect(events.upsertFromExternal('does-not-exist')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
