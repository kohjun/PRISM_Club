import { Controller, HttpCode, Param, Post } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { EventRecapSuggestService } from './event-recap-suggest.service';

@Controller('event-cards')
export class EventRecapSuggestController {
  constructor(
    private readonly recap: EventRecapSuggestService,
  ) {}

  /**
   * P7.3 — return a composer prefill for an event recap. Idempotent;
   * does NOT persist anything (the recap becomes a real post via the
   * usual `POST /v1/rooms/:slug/posts` flow once the organizer hits
   * publish). Gated to COMPLETED events + organizer-eligible viewers
   * by `EventRecapSuggestService.suggestFor`.
   */
  @Post(':id/recap/suggest')
  @HttpCode(200)
  async suggest(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.recap.suggestFor(id, user);
  }
}
