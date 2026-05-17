import { Controller, Get, Param, Query } from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { EventDetailService } from './event-detail.service';

const querySchema = z
  .object({
    posts_limit: z.string().regex(/^\d+$/).optional(),
    posts_cursor: z.string().uuid().optional(),
    rooms_limit: z.string().regex(/^\d+$/).optional(),
  })
  .passthrough();

type Query = z.infer<typeof querySchema>;

@Controller()
export class EventDetailController {
  constructor(private readonly events: EventDetailService) {}

  @Get('event-cards/:id')
  async getDetail(
    @Param('id') id: string,
    @Query(new ZodValidationPipe(querySchema)) query: Query,
    @CurrentUser() user: RequestUser,
  ) {
    return this.events.getBundle(id, user, {
      postsLimit: query.posts_limit ? Number(query.posts_limit) : undefined,
      postsCursor: query.posts_cursor,
      roomsLimit: query.rooms_limit ? Number(query.rooms_limit) : undefined,
    });
  }
}
