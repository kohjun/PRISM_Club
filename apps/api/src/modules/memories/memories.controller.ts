import { Controller, Get, Query } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { MemoriesService } from './memories.service';

@Controller('me')
export class MemoriesController {
  constructor(private readonly memories: MemoriesService) {}

  /**
   * P6.11 — "오늘의 기록". Anniversary timeline of the viewer's own
   * activity 1 and 2 years ago. `date` (YYYY-MM-DD) defaults to today;
   * an unparseable value also falls back to today. Auth-required
   * (me-scoped); empty days return `{ items: [] }` so the mobile card
   * self-hides.
   */
  @Get('memories')
  async getMemories(
    @CurrentUser() user: RequestUser,
    @Query('date') date?: string,
  ) {
    return this.memories.getForUser(user, date);
  }
}
