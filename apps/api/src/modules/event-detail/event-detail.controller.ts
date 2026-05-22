import {
  Controller,
  Get,
  Header,
  Param,
  Query,
} from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { Public } from '../../shared/decorators/public.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { EventDetailService } from './event-detail.service';
import { EventIcsService } from './event-ics.service';

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
  constructor(
    private readonly events: EventDetailService,
    private readonly ics: EventIcsService,
  ) {}

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

  /**
   * RFC 5545 calendar export (P3.4). Returns plain text with the
   * `text/calendar` media type so OS calendar apps recognise the
   * download as an importable event. Public so mobile can hand the
   * URL straight to `url_launcher` without an auth-bearing fetch —
   * the ICS body contains only fields the EventCard already surfaces
   * publicly (title, venue, startsAt).
   */
  @Public()
  @Get('event-cards/:id/ics')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  @Header(
    'Content-Disposition',
    'attachment; filename="prism-event.ics"',
  )
  async getIcs(@Param('id') id: string): Promise<string> {
    return this.ics.buildIcs(id);
  }
}
