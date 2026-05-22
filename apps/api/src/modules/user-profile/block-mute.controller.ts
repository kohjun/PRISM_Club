import {
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { BlockMuteService } from '../../shared/block-mute.service';

/**
 * P6.2 viewer-managed block + mute lists. Lives under `/me/...` so a
 * user can only touch their own relationships — the controller never
 * exposes a path to mutate someone else's lists.
 *
 * Block + unblock are idempotent (re-issuing a block on an already-
 * blocked user is a no-op 200 — never 409) because the typical client
 * flow is "tap → optimistic local state → API confirms".
 */
@Controller()
export class BlockMuteController {
  constructor(private readonly svc: BlockMuteService) {}

  @Get('me/blocks')
  list(@CurrentUser() user: RequestUser) {
    return this.svc.listBlocks(user.id).then((items) => ({ items }));
  }

  @Post('me/blocks/:userId')
  @HttpCode(200)
  async block(
    @Param('userId') userId: string,
    @CurrentUser() user: RequestUser,
  ) {
    await this.svc.block(user.id, userId);
    return { ok: true };
  }

  @Delete('me/blocks/:userId')
  @HttpCode(200)
  async unblock(
    @Param('userId') userId: string,
    @CurrentUser() user: RequestUser,
  ) {
    await this.svc.unblock(user.id, userId);
    return { ok: true };
  }

  @Get('me/mutes')
  listMutes(@CurrentUser() user: RequestUser) {
    return this.svc.listMutes(user.id).then((items) => ({ items }));
  }

  @Post('me/mutes/:userId')
  @HttpCode(200)
  async mute(
    @Param('userId') userId: string,
    @CurrentUser() user: RequestUser,
  ) {
    await this.svc.mute(user.id, userId);
    return { ok: true };
  }

  @Delete('me/mutes/:userId')
  @HttpCode(200)
  async unmute(
    @Param('userId') userId: string,
    @CurrentUser() user: RequestUser,
  ) {
    await this.svc.unmute(user.id, userId);
    return { ok: true };
  }
}
