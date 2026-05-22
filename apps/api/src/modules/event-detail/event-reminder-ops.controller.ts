import { Controller, HttpCode, Post } from '@nestjs/common';
import { Roles } from '../../shared/decorators/roles.decorator';
import { EventReminderCron } from './event-reminder.cron';

@Controller()
export class EventReminderOpsController {
  constructor(private readonly cron: EventReminderCron) {}

  /**
   * Manual reminder tick — runs the same body as the hourly cron.
   * Used to catch up after a deploy hop or to verify the path in
   * staging without waiting an hour.
   */
  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Post('ops/event-reminders/run')
  @HttpCode(200)
  run() {
    return this.cron.runReminderTick(new Date());
  }

  @Roles('ADMIN')
  @Post('ops/event-cards/refresh-status')
  @HttpCode(200)
  refreshStatus() {
    return this.cron.runStatusRefresh(new Date());
  }
}
