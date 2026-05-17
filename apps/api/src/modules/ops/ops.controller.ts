import { Controller, Get } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { OpsService } from './ops.service';

@Controller('admin/ops')
export class OpsController {
  constructor(private readonly svc: OpsService) {}

  @Get('summary')
  summary(@CurrentUser() user: RequestUser) {
    return this.svc.getSummary(user);
  }
}
