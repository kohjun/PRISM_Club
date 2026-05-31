import { Controller, Get, Param } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { CuratorPortfolioService } from './curator-portfolio.service';

@Controller()
export class CuratorPortfolioController {
  constructor(private readonly svc: CuratorPortfolioService) {}

  /**
   * P6.10 — a user's curation footprint (resolved contributions,
   * source-tier rules they introduced, reputation summary). Auth-
   * required because the resolved-contribution list is filtered by the
   * *viewer's* space accessPolicy. `is_curator=false` for users without
   * a curator role — the lists are then naturally empty.
   */
  @Get('profiles/:userId/curator-portfolio')
  portfolio(
    @Param('userId') userId: string,
    @CurrentUser() viewer: RequestUser,
  ) {
    return this.svc.getForUser(userId, viewer);
  }
}
