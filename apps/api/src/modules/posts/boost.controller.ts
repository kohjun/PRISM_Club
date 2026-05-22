import { Controller, HttpCode, Param, Post } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { BoostService } from './boost.service';

/**
 * P6.6 boost endpoints.
 *
 * Toggle is idempotent — a second call removes the boost. We expose
 * a single POST verb because both directions of the toggle take the
 * same input (post id + viewer); the response carries the resolved
 * state so the client knows whether to render the icon as active.
 */
@Controller()
export class BoostController {
  constructor(private readonly boosts: BoostService) {}

  @Post('posts/:postId/boost')
  @HttpCode(200)
  async toggle(
    @Param('postId') postId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.boosts.toggle(postId, user);
  }
}
