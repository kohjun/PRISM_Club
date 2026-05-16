import { Body, Controller, Get, Post, Query, BadRequestException } from '@nestjs/common';
import { EventCardService } from './event-card.service';

@Controller()
export class EventCardController {
  constructor(private readonly events: EventCardService) {}

  @Get('events/search')
  async search(@Query('q') q: string = '', @Query('status') status?: string) {
    const normalizedStatus = status === 'UPCOMING' || status === 'COMPLETED' ? status : undefined;
    const items = await this.events.search(q, normalizedStatus);
    return { items };
  }

  @Post('event-cards')
  async upsert(@Body() body: { external_event_id?: string }) {
    if (!body?.external_event_id || typeof body.external_event_id !== 'string') {
      throw new BadRequestException('external_event_id is required');
    }
    return this.events.upsertFromExternal(body.external_event_id);
  }
}
