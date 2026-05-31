import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { DmService } from './dm.service';
import { CreateDmChannelInput, SendDmMessageInput } from './dto/dm.dto';

@Controller('dm')
export class DmController {
  constructor(private readonly svc: DmService) {}

  /** Resolve-or-create a workflow-scoped channel by {scope, ref_id}. */
  @Post('channels')
  createChannel(
    @CurrentUser() user: RequestUser,
    @Body() body: CreateDmChannelInput,
  ) {
    return this.svc.resolveOrCreateChannel(body, user);
  }

  @Get('channels')
  listChannels(@CurrentUser() user: RequestUser) {
    return this.svc.listChannels(user);
  }

  @Get('channels/:id/messages')
  listMessages(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
  ) {
    return this.svc.listMessages(id, user, { cursor });
  }

  @Post('channels/:id/messages')
  send(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() body: SendDmMessageInput,
  ) {
    return this.svc.send(id, user, body?.body ?? '');
  }

  @Post('channels/:id/read')
  markRead(@CurrentUser() user: RequestUser, @Param('id') id: string) {
    return this.svc.markRead(id, user);
  }
}
