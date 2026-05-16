import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { RoomService } from './room.service';

const createRoomSchema = z.object({
  name: z.string().min(1).max(80),
  description: z.string().max(2000).optional(),
  room_type: z.enum(['DISCUSSION', 'EVENT_REACTION', 'REFERENCE', 'IDEA', 'RECRUITMENT', 'SOCIAL']),
  tags: z.array(z.string().max(40)).max(10).optional(),
  pinned_event_card_id: z.string().uuid().optional(),
  pinned_reference_id: z.string().uuid().optional(),
});

type CreateRoomBody = z.infer<typeof createRoomSchema>;

@Controller()
export class RoomController {
  constructor(private readonly rooms: RoomService) {}

  @Get('categories/:slug/rooms')
  async listInCategory(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return { items: await this.rooms.listByCategorySlug(slug, user) };
  }

  @Post('categories/:slug/rooms')
  @HttpCode(201)
  async create(
    @Param('slug') slug: string,
    @Body(new ZodValidationPipe(createRoomSchema)) body: CreateRoomBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.rooms.createUserRoom(slug, body, user.id, user);
  }

  @Get('rooms/:slug')
  async getRoom(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return this.rooms.getRoomDetailBySlug(slug, user);
  }
}
