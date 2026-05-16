import { NotFoundException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { RoomService } from './room.service';

describe('RoomService', () => {
  let ctx: TestContext;
  let rooms: RoomService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    rooms = ctx.app.get(RoomService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('createUserRoom with both pins resolves them', async () => {
    const room = await rooms.createUserRoom(
      'love-content',
      {
        name: 'unit-test room',
        description: 'desc',
        room_type: 'DISCUSSION',
        pinned_event_card_id: ctx.uuids.event.e002,
        pinned_reference_id: ctx.uuids.reference.firstMeetingIdeas,
      },
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo),
    );

    expect(room.origin).toBe('USER');
    expect(room.owner?.id).toBe(ctx.uuids.user.minseo);
    expect(room.pins).toHaveLength(2);
    const types = room.pins.map((p) => p.target_type).sort();
    expect(types).toEqual(['EVENT_CARD', 'REFERENCE']);
  });

  test('createUserRoom slug stays unique even with duplicate names', async () => {
    const a = await rooms.createUserRoom(
      'love-content',
      { name: 'duplicate name', room_type: 'DISCUSSION' },
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo),
    );
    const b = await rooms.createUserRoom(
      'love-content',
      { name: 'duplicate name', room_type: 'DISCUSSION' },
      ctx.uuids.user.joon,
      asUser(ctx.uuids.user.joon),
    );
    expect(b.slug).not.toBe(a.slug);
  });

  test('createUserRoom rejects unknown event-card pin', async () => {
    await expect(
      rooms.createUserRoom(
        'love-content',
        {
          name: 'bad pin',
          room_type: 'DISCUSSION',
          pinned_event_card_id: '00000000-0000-0000-0000-000000000000',
        },
        ctx.uuids.user.minseo,
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
