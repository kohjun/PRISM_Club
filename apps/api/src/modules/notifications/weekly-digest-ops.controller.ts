import { Controller, HttpCode, Post } from '@nestjs/common';
import { Roles } from '../../shared/decorators/roles.decorator';
import { WeeklyDigestService } from './weekly-digest.service';

@Controller()
export class WeeklyDigestOpsController {
  constructor(private readonly svc: WeeklyDigestService) {}

  /**
   * Manual catch-up tick. Useful after a deploy hop that landed
   * mid-Sunday or when staging-verifying the path without waiting a
   * full week.
   */
  @Roles('ADMIN')
  @Post('ops/weekly-digest/run')
  @HttpCode(200)
  run() {
    return this.svc.run();
  }
}
