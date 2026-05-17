import { Controller, Get, Param, Post } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { SignalService } from './signal.service';

@Controller()
export class SignalController {
  constructor(private readonly svc: SignalService) {}

  @Post('admin/signals/refresh')
  refreshAll(@CurrentUser() user: RequestUser) {
    return this.svc.refreshAll(user);
  }

  @Get('topic-hubs/:id/signals')
  listForHub(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.svc.listForHub(id, user);
  }
}
