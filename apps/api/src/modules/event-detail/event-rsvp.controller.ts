import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { EventRsvpService } from './event-rsvp.service';

interface SetRsvpBody {
  status?: string;
}

@Controller()
export class EventRsvpController {
  constructor(private readonly svc: EventRsvpService) {}

  @Post('event-cards/:id/rsvp')
  @HttpCode(200)
  setRsvp(
    @Param('id') eventCardId: string,
    @Body() body: SetRsvpBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.setRsvp(eventCardId, user.id, body?.status ?? '');
  }

  @Delete('event-cards/:id/rsvp')
  @HttpCode(200)
  removeRsvp(
    @Param('id') eventCardId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.removeRsvp(eventCardId, user.id);
  }

  @Get('event-cards/:id/rsvp-state')
  state(
    @Param('id') eventCardId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.getState(eventCardId, user.id);
  }

  @Get('me/rsvps')
  listMine(
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listMine(user.id, {
      status,
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }
}
