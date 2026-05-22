import {
  Body,
  Controller,
  Delete,
  HttpCode,
  Param,
  Post,
} from '@nestjs/common';
import { z } from 'zod';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ZodValidationPipe } from '../../shared/pipes/zod-validation.pipe';
import { PollService } from './poll.service';

const voteSchema = z.object({
  option_id: z.string().uuid(),
});

type VoteBody = z.infer<typeof voteSchema>;

@Controller()
export class PollController {
  constructor(private readonly polls: PollService) {}

  @Post('polls/:pollId/votes')
  @HttpCode(200)
  async vote(
    @Param('pollId') pollId: string,
    @Body(new ZodValidationPipe(voteSchema)) body: VoteBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.polls.vote(pollId, body.option_id, user);
  }

  /**
   * Clears all of the viewer's votes on this poll. Used by the mobile
   * "투표 취소" action when the user wants to back out entirely on a
   * multi-choice poll. Single-choice clients can also call this — same
   * effect as voting the same option twice.
   */
  @Delete('polls/:pollId/votes')
  @HttpCode(200)
  async clear(
    @Param('pollId') pollId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.polls.clearVotes(pollId, user);
  }
}
